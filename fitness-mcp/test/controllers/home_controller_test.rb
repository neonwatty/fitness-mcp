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
    user = create_user(email: "test@example.com", password: "password123")
    
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    get "/dashboard"
    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_select "form[data-target='log-set']"
    assert_select "form[data-target='get-history']"
    assert_select "form[data-target='create-plan']"
  end

  test "should redirect to login when accessing dashboard without login" do
    get "/dashboard"
    assert_redirected_to "/login"
    follow_redirect!
    assert_select ".bg-red-100", text: "Please log in first"
  end

  test "dashboard should show API testing interface" do
    user = create_user(email: "test@example.com", password: "password123")
    
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    get "/dashboard"
    assert_response :success
    
    # Check for API testing sections
    assert_select "h3", text: "Log a Set"
    assert_select "h3", text: "Get Workout History"
    assert_select "h3", text: "Create Workout Plan"
    assert_select "h3", text: "API Key Management"
    
    # Check for form inputs
    assert_select "input[name='exercise']"
    assert_select "input[name='weight']"
    assert_select "input[name='reps']"
    assert_select "input[name='limit']"
    assert_select "input[name='assignment_name']"
    assert_select "input[name='scheduled_for']"
    assert_select "input[name='api_key_name']"
  end
end