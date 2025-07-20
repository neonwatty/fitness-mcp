require "test_helper"

class WebSessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(password: "password123")
  end

  test "should get new" do
    get "/login"
    assert_response :success
    assert_select "form[action='/login']"
    assert_select "input[name='email']"
    assert_select "input[name='password']"
  end

  test "should create session with valid credentials" do
    post "/login", params: {
      email: @user.email,
      password: "password123"
    }
    
    assert_redirected_to "/dashboard"
    follow_redirect!
    assert_select ".alert-success", text: "Login successful!"
  end

  test "should not create session with invalid credentials" do
    post "/login", params: {
      email: @user.email,
      password: "wrong_password"
    }
    
    assert_response :success
    assert_select ".alert-error", text: "Invalid email or password"
  end

  test "should not create session with missing credentials" do
    post "/login", params: {
      email: @user.email
    }
    
    assert_response :success
    assert_select ".alert-error", text: "Invalid email or password"
  end

  test "should destroy session" do
    # First login
    post "/login", params: {
      email: @user.email,
      password: "password123"
    }
    
    # Then logout
    delete "/logout"
    assert_redirected_to "/"
    follow_redirect!
    assert_select ".alert-success", text: "Logout successful!"
  end
end