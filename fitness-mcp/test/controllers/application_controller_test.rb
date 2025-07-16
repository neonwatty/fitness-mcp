require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  # ApplicationController is abstract, but we can test it through HomeController
  test "should include basic Rails controller functionality" do
    get root_url
    assert_response :success
  end
  
  test "should have access to session" do
    user = create_user(email: "app_test@example.com", password: "password")
    post "/login", params: { email: "app_test@example.com", password: "password" }
    assert_redirected_to dashboard_path
    
    follow_redirect!
    assert_response :success
  end
  
  test "should return API info" do
    get "/api_info"
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal "Fitness MCP Server", json["name"]
    assert_equal "1.0.0", json["version"]
    assert json["description"]
    assert json["endpoints"]
    assert_instance_of Array, json["features"]
    assert json["features"].include?("Model Context Protocol (MCP) integration")
  end
end