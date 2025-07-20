require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get "/"
    assert_response :success
    assert_select "h1", text: "Fitness MCP Server"
    assert_select "a[href='/register']"
    assert_select "a[href='/login']"
  end

  test "should get dashboard when logged in" do
    user = create_user(password: "password123")
    
    # Login first
    post "/login", params: {
      email: user.email,
      password: "password123"
    }
    
    get "/dashboard"
    assert_response :success
    assert_select "h1", text: "Welcome back, #{user.email}"
    assert_select "h2", text: "API Key Management"
    assert_select "h2", text: "API Testing Interface"
  end

  test "should redirect to login when accessing dashboard without login" do
    get "/dashboard"
    assert_redirected_to "/login"
    follow_redirect!
    assert_select ".alert-error", text: "Please log in first"
  end

  test "dashboard should show API testing interface" do
    user = create_user(password: "password123")
    
    # Login first
    post "/login", params: {
      email: user.email,
      password: "password123"
    }
    
    get "/dashboard"
    assert_response :success
    
    # Check for API testing sections
    assert_select "h3", text: "Quick Actions"
    assert_select "h4", text: "Log Workout Set"
    assert_select "h4", text: "Get Last Set"
    assert_select "h4", text: "Get Last N Sets"
    assert_select "h3", text: "API Response"
    
    # Check for form inputs
    assert_select "input[id='exercise']"
    assert_select "input[id='weight']"
    assert_select "input[id='reps']"
    assert_select "input[id='sets-limit']"
    assert_select "input[id='api-key-input']"
  end
end