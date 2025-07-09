require "application_system_test_case"

class JavascriptApiEndpointsTest < ApplicationSystemTestCase
  # This test would have caught the JavaScript endpoint bug!
  
  test "dashboard JavaScript calls valid API endpoints" do
    # Extract API endpoints from the dashboard JavaScript
    dashboard_view = File.read(Rails.root.join("app/views/home/dashboard.html.erb"))
    
    # Find all makeApiCall invocations in the JavaScript
    api_calls = dashboard_view.scan(/makeApiCall\(['"`]([^'"`]+)['"`]/)
    
    # These are the endpoints the JavaScript actually calls
    javascript_endpoints = api_calls.flatten
    
    puts "JavaScript endpoints found: #{javascript_endpoints.inspect}"
    
    # Verify each JavaScript endpoint has a corresponding Rails route
    javascript_endpoints.each do |endpoint|
      # Remove query parameters for route checking
      route_path = endpoint.split('?').first
      
      # Check if route exists by trying to recognize it
      route_found = false
      route_info = nil
      
      %w[get post patch delete].each do |method|
        begin
          route_info = Rails.application.routes.recognize_path(route_path, method: method.to_sym)
          route_found = true
          puts "✓ Route found for #{endpoint}: #{method.upcase} -> #{route_info}"
          break
        rescue ActionController::RoutingError
          # Try next method
        end
      end
      
      assert route_found, "No route found for JavaScript endpoint: #{endpoint}"
    end
  end

  test "all dashboard Quick Actions buttons trigger valid API calls" do
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    
    # Create API key first
    click_button "Create New API Key"
    page.driver.browser.switch_to.alert.send_keys("Test API Key")
    page.driver.browser.switch_to.alert.accept
    sleep 1
    page.driver.browser.switch_to.alert.accept
    
    # Test each Quick Action button to ensure they call valid endpoints
    # If the endpoints were wrong, these would fail with 404 errors
    
    # Test 1: Log Set button
    fill_in "exercise", with: "Test Exercise"
    fill_in "weight", with: "100"
    fill_in "reps", with: "5"
    
    # Monitor network requests in browser dev tools (if available)
    # This button should NOT result in a 404 error
    click_button "Log Set"
    
    # Wait for response - if endpoint is wrong, this would timeout or show error
    wait_for_api_response
    
    response = get_api_response_json
    # If endpoint was wrong, response would be HTML, not JSON
    assert response.is_a?(Hash), "Response should be JSON, not HTML (indicates 404 error)"
    
    # Test 2: Get Last Set button  
    fill_in "get-exercise", with: "Test Exercise"
    click_button "Get Last Set"
    
    wait_for_api_response
    
    response = get_api_response_json
    assert response.is_a?(Hash), "Get Last Set should return JSON, not HTML"
    
    # Test 3: Get Last N Sets button
    fill_in "get-sets-exercise", with: "Test Exercise"
    fill_in "sets-limit", with: "3"
    click_button "Get Sets"
    
    wait_for_api_response
    
    response = get_api_response_json
    assert response.is_a?(Hash), "Get Sets should return JSON, not HTML"
  end

  test "dashboard API calls return proper JSON content-type" do
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    
    # Create API key
    click_button "Create New API Key"
    page.driver.browser.switch_to.alert.send_keys("Content-Type Test Key")
    page.driver.browser.switch_to.alert.accept
    sleep 1
    page.driver.browser.switch_to.alert.accept
    
    # Make an API call and verify response content-type
    fill_in "exercise", with: "Content Test"
    fill_in "weight", with: "100"
    fill_in "reps", with: "5"
    
    click_button "Log Set"
    
    wait_for_api_response
    
    # If the endpoint returned HTML (404 error), the response would start with '<'
    response_text = find("#api-results pre").text
    assert_not response_text.start_with?('<'), "Response should not be HTML (indicates wrong endpoint)"
    
    # Should be valid JSON
    response = JSON.parse(response_text)
    assert response["success"] || response["error"], "Response should be valid API JSON"
  end

  private

  def wait_for_api_response
    # Wait for API response to appear in the results panel
    assert_selector "#api-results pre", wait: 10
  end

  def get_api_response_json
    # Extract and parse JSON from the API results panel  
    response_text = find("#api-results pre").text
    JSON.parse(response_text)
  rescue JSON::ParserError => e
    flunk "API response is not valid JSON: #{response_text}. Error: #{e.message}"
  end
end