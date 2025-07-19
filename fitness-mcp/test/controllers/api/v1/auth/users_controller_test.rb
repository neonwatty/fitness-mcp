require "test_helper"

class Api::V1::Auth::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should create user with valid data" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "newuser@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "User registered successfully", json["message"]
    assert json["user"]["id"]
    assert_equal "newuser@example.com", json["user"]["email"]
    assert json["user"]["created_at"]
    
    # Verify the user was actually created
    user = User.find_by(email: "newuser@example.com")
    assert_not_nil user
    assert user.authenticate("password123")
  end
  
  test "should not create user with missing email" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
    assert json["errors"]
  end
  
  test "should not create user with missing password" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password_confirmation: "password123"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
    assert json["errors"]
  end
  
  test "should not create user with mismatched password confirmation" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "different123"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
    assert json["errors"]
  end
  
  test "should create user without password confirmation if not provided" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123"
           }
         }
    
    # has_secure_password doesn't require confirmation unless explicitly provided
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "User registered successfully", json["message"]
  end
  
  test "should not create user with duplicate email" do
    # Create a user first
    create_user(email: "existing@example.com")
    
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "existing@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
    assert json["errors"]
  end
  
  test "should not create user with missing user params" do
    post "/api/v1/auth/register", params: {}
    
    assert_response :bad_request
  end
  
  test "should not create user with empty user params" do
    post "/api/v1/auth/register", params: { user: {} }
    
    # Empty user params should trigger strong parameters error (400)
    assert_response :bad_request
  end
  
  test "should skip verify_authenticity_token for user creation" do
    # This is implicitly tested by all POST requests working without CSRF tokens
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
  end
  
  test "should not require API key for user creation" do
    # User creation should work without API key
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
  end
  
  test "user response should only include safe fields" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    user_data = json["user"]
    
    # Should only include id, email, and created_at
    assert_equal 3, user_data.keys.length
    assert user_data.key?("id")
    assert user_data.key?("email")
    assert user_data.key?("created_at")
    assert_not user_data.key?("password_digest")
    assert_not user_data.key?("updated_at")
  end
  
  test "should create user with valid email format" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "test@example.com", json["user"]["email"]
  end
  
  test "should create user with different email formats" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "user.name+tag@example.co.uk",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "user.name+tag@example.co.uk", json["user"]["email"]
  end
  
  test "should handle empty email" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
  end
  
  test "should handle nil email" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: nil,
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
  end
  
  test "should handle empty password" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "",
             password_confirmation: ""
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
  end
  
  test "should handle nil password" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: nil,
             password_confirmation: nil
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
  end
  
  test "should skip API key authentication for create" do
    # This action should work without API key unlike other BaseController actions
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
  end
  
  test "created_at should be a valid timestamp" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    created_at = json["user"]["created_at"]
    
    # Should be a valid timestamp
    assert_not_nil created_at
    assert_instance_of String, created_at
    
    # Should be parseable as a time
    assert_nothing_raised do
      Time.parse(created_at)
    end
  end
  
  test "should return 422 for validation errors" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "",
             password: "password123",
             password_confirmation: "different"
           }
         }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Registration failed", json["message"]
    assert json["errors"]
  end
  
  test "should return 201 for successful creation" do
    post "/api/v1/auth/register", 
         params: { 
           user: {
             email: "test@example.com",
             password: "password123",
             password_confirmation: "password123"
           }
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "User registered successfully", json["message"]
  end
end