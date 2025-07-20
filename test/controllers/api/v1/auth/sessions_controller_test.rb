require "test_helper"

class Api::V1::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(password: "password123")
    @api_key_record, @api_key = create_api_key(user: @user)
  end

  test "should create session with valid credentials" do
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email, 
           password: "password123" 
         }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Login successful", json["message"]
    assert json["user"]["id"]
    assert_equal @user.email, json["user"]["email"]
    assert json["user"]["created_at"]
    
    # This controller doesn't create API keys, just validates credentials
    assert_equal 1, @user.api_keys.count
  end
  
  test "should not create session with invalid email" do
    post "/api/v1/auth/login", 
         params: { 
           email: "wrong@example.com", 
           password: "password123" 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should not create session with invalid password" do
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email, 
           password: "wrong_password" 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should not create session with missing email" do
    post "/api/v1/auth/login", 
         params: { 
           password: "password123" 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should not create session with missing password" do
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should not create session with missing params" do
    post "/api/v1/auth/login", params: {}
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should not create session for non-existent user" do
    post "/api/v1/auth/login", 
         params: { 
           email: "nonexistent@example.com", 
           password: "password123" 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should destroy session with valid API key" do
    delete "/api/v1/auth/logout", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Logout successful", json["message"]
  end
  
  test "should not destroy session without API key" do
    delete "/api/v1/auth/logout"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should not destroy session with invalid API key" do
    delete "/api/v1/auth/logout", headers: api_headers("invalid_key_12345")
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should not destroy session with revoked API key" do
    @api_key_record.revoke!
    
    delete "/api/v1/auth/logout", headers: api_headers(@api_key)
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should handle Bearer token format in destroy" do
    delete "/api/v1/auth/logout", headers: { 'Authorization' => "Bearer #{@api_key}" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Logout successful", json["message"]
  end
  
  test "should handle token without Bearer prefix in destroy" do
    delete "/api/v1/auth/logout", headers: { 'Authorization' => @api_key }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Logout successful", json["message"]
  end
  
  test "should skip verify_authenticity_token for sessions" do
    # This is implicitly tested by all POST/DELETE requests working without CSRF tokens
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email, 
           password: "password123" 
         }
    
    assert_response :success
  end
  
  test "user response should only include safe fields" do
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email, 
           password: "password123" 
         }
    
    assert_response :success
    json = JSON.parse(response.body)
    user_data = json["user"]
    
    # Should include id, email, and created_at
    assert_equal 3, user_data.keys.length
    assert user_data.key?("id")
    assert user_data.key?("email")
    assert user_data.key?("created_at")
    assert_not user_data.key?("password_digest")
    assert_not user_data.key?("updated_at")
  end
  
  test "should skip API key authentication for login" do
    # Login should work without API key
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email, 
           password: "password123" 
         }
    
    assert_response :success
  end
  
  test "should require API key authentication for logout" do
    # Logout should require API key (inherits from BaseController)
    delete "/api/v1/auth/logout"
    
    assert_response :unauthorized
  end
  
  test "should handle empty string email" do
    post "/api/v1/auth/login", 
         params: { 
           email: "", 
           password: "password123" 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
  
  test "should handle empty string password" do
    post "/api/v1/auth/login", 
         params: { 
           email: @user.email, 
           password: "" 
         }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
end