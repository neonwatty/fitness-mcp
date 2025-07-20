require 'test_helper'

class OauthIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '123456789',
      info: {
        email: 'oauth@example.com',
        name: 'OAuth Test User',
        image: 'https://example.com/avatar.jpg'
      }
    })
  end
  
  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
  
  test "complete OAuth flow for new user" do
    # Start at login page
    get '/login'
    assert_response :success
    assert_select 'a[href="/auth/google_oauth2"]', text: /Sign in with Google/
    
    # Simulate OAuth callback
    assert_difference 'User.count', 1 do
      get '/auth/google_oauth2/callback'
    end
    
    # Should redirect to dashboard
    assert_redirected_to dashboard_path
    follow_redirect!
    
    # Check success message and user info
    assert_select '.alert-success', text: 'Successfully signed in with Google!'
    assert_select 'h1', text: 'Welcome back, OAuth Test User'
    
    # Verify user was created with OAuth data
    user = User.last
    assert_equal 'oauth@example.com', user.email
    assert_equal 'google_oauth2', user.provider
    assert_equal '123456789', user.uid
    assert_equal 'OAuth Test User', user.name
    assert_equal 'https://example.com/avatar.jpg', user.image_url
    assert user.oauth_user?
    assert user.has_password? # OAuth users get random password, so they have password_digest
    
    # Check that user is logged in
    assert session[:user_id] == user.id
    
    # Verify dashboard shows OAuth user info
    assert_select '.text-secondary-400', text: /Welcome, oauth@example.com/
    
    # Test logout
    delete '/logout'
    assert_redirected_to root_path
    follow_redirect!
    assert_select '.alert-success', text: 'Logout successful!'
    assert_nil session[:user_id]
  end
  
  test "OAuth flow for existing email user links accounts" do
    # Create existing user with email/password
    existing_user = User.create!(
      email: 'oauth@example.com',
      password: 'password123'
    )
    initial_count = User.count
    
    # Simulate OAuth callback
    assert_no_difference 'User.count' do
      get '/auth/google_oauth2/callback'
    end
    
    # Should redirect to dashboard
    assert_redirected_to dashboard_path
    follow_redirect!
    
    # Check success message
    assert_select '.alert-success', text: 'Successfully signed in with Google!'
    
    # Verify existing user was updated with OAuth data
    existing_user.reload
    assert_equal 'google_oauth2', existing_user.provider
    assert_equal '123456789', existing_user.uid
    assert_equal 'OAuth Test User', existing_user.name
    assert_equal 'https://example.com/avatar.jpg', existing_user.image_url
    assert existing_user.oauth_user?
    assert existing_user.has_password? # Should still have password
    
    # Check that correct user is logged in
    assert session[:user_id] == existing_user.id
  end
  
  test "OAuth flow from register page" do
    # Start at register page
    get '/register'
    assert_response :success
    assert_select 'a[href="/auth/google_oauth2"]', text: /Sign up with Google/
    
    # Simulate OAuth callback
    assert_difference 'User.count', 1 do
      get '/auth/google_oauth2/callback'
    end
    
    # Should redirect to dashboard
    assert_redirected_to dashboard_path
    follow_redirect!
    
    # Check success message
    assert_select '.alert-success', text: 'Successfully signed in with Google!'
    
    # Verify user was created
    user = User.last
    assert_equal 'oauth@example.com', user.email
    assert user.oauth_user?
    assert session[:user_id] == user.id
  end
  
  test "OAuth failure redirects properly" do
    # Test OAuth failure
    get '/auth/failure?message=invalid_credentials'
    
    assert_redirected_to login_path
    follow_redirect!
    
    assert_select '.alert-error', text: 'Authentication failed: Invalid credentials'
    assert_nil session[:user_id]
  end
  
  test "OAuth user can access API functionality" do
    # Create OAuth user
    get '/auth/google_oauth2/callback'
    follow_redirect!
    
    user = User.last
    
    # Test API key creation via web interface (responds with JSON)
    post '/api_keys', params: { api_key: { name: 'Test OAuth Key' } }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal true, response_data['success']
    assert_equal 'API key created successfully', response_data['message']
    
    api_key = user.api_keys.last
    assert_not_nil api_key
    assert_equal 'Test OAuth Key', api_key.name
  end
  
  test "OAuth user session persists across requests" do
    # OAuth login
    get '/auth/google_oauth2/callback'
    user = User.last
    
    # Multiple page visits should maintain session
    get '/dashboard'
    assert_response :success
    assert session[:user_id] == user.id
    
    get '/api_info'
    assert_response :success
    
    get '/'
    assert_response :success
    
    # Session should still be valid
    get '/dashboard'
    assert_response :success
    assert session[:user_id] == user.id
  end
  
  test "OAuth authentication with CSRF protection" do
    # Ensure CSRF protection is working
    ActionController::Base.allow_forgery_protection = true
    
    begin
      get '/auth/google_oauth2/callback'
      assert_redirected_to dashboard_path
      
      # OAuth should work despite CSRF protection
      follow_redirect!
      assert_select '.alert-success', text: 'Successfully signed in with Google!'
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end