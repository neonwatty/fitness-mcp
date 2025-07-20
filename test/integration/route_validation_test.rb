require "test_helper"

class RouteValidationTest < ActionDispatch::IntegrationTest
  # This test would have caught the JavaScript endpoint bug immediately!
  
  test "all dashboard JavaScript API calls have corresponding Rails routes" do
    # Read the dashboard view file
    dashboard_view = File.read(Rails.root.join("app/views/home/dashboard.html.erb"))
    
    # Extract all API endpoints called by JavaScript
    javascript_endpoints = []
    
    # Find makeApiCall invocations
    dashboard_view.scan(/makeApiCall\(['"`]([^'"`]+)['"`]/) do |match|
      endpoint = match[0].split('?').first  # Remove query parameters
      javascript_endpoints << endpoint
    end
    
    puts "Found JavaScript API endpoints: #{javascript_endpoints.inspect}"
    
    # Verify each endpoint has a corresponding Rails route
    javascript_endpoints.each do |endpoint|
      route_exists = false
      
      # Try different HTTP methods
      %w[GET POST PATCH DELETE].each do |method|
        begin
          route_info = Rails.application.routes.recognize_path(endpoint, method: method.downcase.to_sym)
          route_exists = true
          puts "✓ #{method} #{endpoint} -> #{route_info[:controller]}##{route_info[:action]}"
          break
        rescue ActionController::RoutingError
          # Continue to next method
        end
      end
      
      assert route_exists, "No Rails route found for JavaScript endpoint: #{endpoint}"
    end
  end

  test "dashboard JavaScript endpoints match expected API patterns" do
    # Read the dashboard view file
    dashboard_view = File.read(Rails.root.join("app/views/home/dashboard.html.erb"))
    
    # Extract API endpoints
    javascript_endpoints = []
    dashboard_view.scan(/makeApiCall\(['"`]([^'"`]+)['"`]/) do |match|
      endpoint = match[0].split('?').first
      javascript_endpoints << endpoint
    end
    
    # Verify endpoints follow expected patterns
    javascript_endpoints.each do |endpoint|
      # All API endpoints should start with /api/v1/
      assert endpoint.start_with?('/api/v1/'), "API endpoint should start with /api/v1/: #{endpoint}"
      
      # Fitness-related endpoints should be under /api/v1/fitness/
      if endpoint.include?('log_set') || endpoint.include?('get_last')
        assert endpoint.start_with?('/api/v1/fitness/'), "Fitness endpoints should be under /api/v1/fitness/: #{endpoint}"
      end
    end
  end

  test "specific fitness API endpoints are correctly defined in JavaScript" do
    # Read the dashboard view file
    dashboard_view = File.read(Rails.root.join("app/views/home/dashboard.html.erb"))
    
    # Check for specific endpoints that should exist
    expected_endpoints = [
      '/api/v1/fitness/log_set',
      '/api/v1/fitness/get_last_set',
      '/api/v1/fitness/get_last_sets'
    ]
    
    expected_endpoints.each do |expected_endpoint|
      assert dashboard_view.include?(expected_endpoint), "Dashboard JavaScript should call #{expected_endpoint}"
    end
    
    # Check for incorrect endpoints that should NOT exist
    incorrect_endpoints = [
      '/api/v1/log_set',           # Missing /fitness/
      '/api/v1/get_last_set',      # Missing /fitness/
      '/api/v1/get_last_sets'      # Missing /fitness/
    ]
    
    incorrect_endpoints.each do |incorrect_endpoint|
      assert_not dashboard_view.include?(incorrect_endpoint), "Dashboard JavaScript should NOT call #{incorrect_endpoint}"
    end
  end

  test "all Rails fitness API routes are properly accessible" do
    # Get all fitness-related routes
    fitness_routes = Rails.application.routes.routes.select do |route|
      route.path.spec.to_s.include?('/api/v1/fitness/')
    end
    
    # Verify each route is accessible
    fitness_routes.each do |route|
      path = route.path.spec.to_s.gsub(/\(\.\:format\)$/, '')
      method = route.verb.downcase.to_sym
      
      # Skip routes that require parameters
      next if path.include?(':id')
      
      puts "Testing route: #{method.upcase} #{path}"
      
      # Make a request to verify route exists (will fail auth, but shouldn't 404)
      case method
      when :get
        get path
      when :post
        post path
      when :patch
        patch path
      when :delete
        delete path
      end
      
      # Should not get 404 (route not found)
      assert_not_equal 404, response.status, "Route should exist: #{method.upcase} #{path}"
    end
  end

  test "dashboard JavaScript uses correct HTTP methods for API calls" do
    dashboard_view = File.read(Rails.root.join("app/views/home/dashboard.html.erb"))
    
    # Extract method and endpoint pairs
    api_calls = dashboard_view.scan(/makeApiCall\(['"`]([^'"`]+)['"`],\s*['"`]([^'"`]+)['"`]/)
    
    expected_methods = {
      '/api/v1/fitness/log_set' => 'POST',
      '/api/v1/fitness/get_last_set' => 'GET',
      '/api/v1/fitness/get_last_sets' => 'GET'
    }
    
    api_calls.each do |endpoint, method|
      endpoint = endpoint.split('?').first  # Remove query parameters
      
      if expected_methods[endpoint]
        assert_equal expected_methods[endpoint], method.upcase, 
                     "#{endpoint} should use #{expected_methods[endpoint]} method, not #{method}"
      end
    end
  end
end