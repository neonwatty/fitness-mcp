require "test_helper"

class ApiAuthTest < ActionDispatch::IntegrationTest
  test "should register new user" do
    post "/api/v1/auth/register", params: {
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
    assert json["user"].present?
    assert_equal "test@example.com", json["user"]["email"]
  end

  test "should not register user with invalid data" do
    post "/api/v1/auth/register", params: {
      user: {
        email: "invalid-email",
        password: "short",
        password_confirmation: "different"
      }
    }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert json["errors"].present?
  end

  test "should not register user with duplicate email" do
    existing_user = create_user
    
    post "/api/v1/auth/register", params: {
      user: {
        email: existing_user.email,
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["errors"]["email"], "has already been taken"
  end

  test "should login user with valid credentials" do
    user = create_user(password: "password123")
    
    post "/api/v1/auth/login", params: {
      email: user.email,
      password: "password123"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Login successful", json["message"]
    assert json["user"].present?
    assert_equal user.email, json["user"]["email"]
  end

  test "should not login user with invalid credentials" do
    user = create_user(password: "password123")
    
    post "/api/v1/auth/login", params: {
      email: "test@example.com",
      password: "wrong_password"
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end

  test "should not login with missing credentials" do
    post "/api/v1/auth/login", params: {
      email: "test@example.com"
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Invalid credentials", json["message"]
  end
end