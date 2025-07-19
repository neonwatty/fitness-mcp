require "test_helper"

class WebUsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get "/register"
    assert_response :success
    assert_select "form"
    assert_select "input[name='user[email]']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "should create user with valid data" do
    assert_difference "User.count", 1 do
      post "/register", params: {
        user: {
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    
    assert_redirected_to "/dashboard"
    follow_redirect!
    assert_select ".alert-success", text: "Account created successfully!"
  end

  test "should not create user with invalid data" do
    assert_no_difference "User.count" do
      post "/register", params: {
        user: {
          email: "invalid-email",
          password: "short",
          password_confirmation: "different"
        }
      }
    end
    
    assert_response :success
    assert_select ".alert-error"
  end

  test "should not create user with duplicate email" do
    create_user(email: "existing@example.com")
    
    assert_no_difference "User.count" do
      post "/register", params: {
        user: {
          email: "existing@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    
    assert_response :success
    assert_select ".alert-error"
  end
end