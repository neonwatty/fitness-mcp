require 'test_helper'

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '123456',
      info: {
        email: 'test@example.com',
        name: 'Test User',
        image: 'https://example.com/image.jpg'
      }
    })
  end
  
  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
  
  test "successful google oauth login creates new user" do
    assert_difference 'User.count', 1 do
      get '/auth/google_oauth2/callback'
    end
    
    assert_redirected_to dashboard_path
    assert_equal 'Successfully signed in with Google!', flash[:notice]
    assert session[:user_id].present?
    
    user = User.last
    assert_equal 'test@example.com', user.email
    assert_equal 'google_oauth2', user.provider
    assert_equal '123456', user.uid
  end
  
  test "successful google oauth login finds existing user" do
    existing_user = User.create!(
      email: 'test@example.com',
      password: 'password123'
    )
    
    assert_no_difference 'User.count' do
      get '/auth/google_oauth2/callback'
    end
    
    assert_redirected_to dashboard_path
    assert_equal existing_user.id, session[:user_id]
    
    existing_user.reload
    assert_equal 'google_oauth2', existing_user.provider
    assert_equal '123456', existing_user.uid
  end
  
  test "oauth failure redirects to login" do
    get '/auth/failure?message=invalid_credentials'
    
    assert_redirected_to login_path
    assert_equal 'Authentication failed: Invalid credentials', flash[:alert]
  end
  
  test "oauth error handling" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    
    get '/auth/google_oauth2/callback'
    
    assert_redirected_to login_path
    assert_match /Authentication failed/, flash[:alert]
  end
end