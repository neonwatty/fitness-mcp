require 'test_helper'

class UserOauthTest < ActiveSupport::TestCase
  test "creates new user from oauth" do
    auth = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '123456',
      info: {
        email: 'newuser@example.com',
        name: 'New User',
        image: 'https://example.com/image.jpg'
      }
    })
    
    assert_difference 'User.count', 1 do
      user = User.from_omniauth(auth)
      assert user.persisted?
      assert_equal 'google_oauth2', user.provider
      assert_equal '123456', user.uid
      assert_equal 'newuser@example.com', user.email
      assert_equal 'New User', user.name
      assert_equal 'https://example.com/image.jpg', user.image_url
    end
  end
  
  test "finds existing user by email and links oauth" do
    existing_user = users(:one)
    # Make sure the user doesn't have oauth provider initially
    assert_nil existing_user.provider
    assert_nil existing_user.uid
    
    auth = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '123456',
      info: {
        email: existing_user.email,
        name: 'Existing User',
        image: 'https://example.com/image.jpg'
      }
    })
    
    assert_no_difference 'User.count' do
      user = User.from_omniauth(auth)
      assert_equal existing_user.id, user.id
      
      # Reload to get updated attributes
      user.reload
      assert_equal 'google_oauth2', user.provider
      assert_equal '123456', user.uid
      assert_equal 'Existing User', user.name
      assert_equal 'https://example.com/image.jpg', user.image_url
    end
  end
  
  test "oauth_user? returns true for oauth users" do
    user = User.new(provider: 'google_oauth2', uid: '123456')
    assert user.oauth_user?
  end
  
  test "oauth_user? returns false for email users" do
    user = User.new(provider: nil, uid: nil)
    assert_not user.oauth_user?
  end
  
  test "password not required for oauth users" do
    user = User.new(
      email: 'oauth@example.com',
      provider: 'google_oauth2',
      uid: '123456'
    )
    user.password = nil
    assert user.valid?
  end
  
  test "password required for non-oauth users" do
    user = User.new(
      email: 'regular@example.com',
      provider: nil,
      uid: nil
    )
    user.password = nil
    assert_not user.valid?
    assert user.errors[:password].present?
  end
  
  test "has_password? returns true for users with password_digest" do
    # Test regular user with password
    user_with_password = users(:one)
    assert user_with_password.has_password?
    
    # Test OAuth user without password_digest
    oauth_user = User.new(
      email: 'oauth@example.com',
      provider: 'google_oauth2',
      uid: '123456',
      password_digest: nil
    )
    assert_not oauth_user.has_password?
  end
  
  test "password_required? with various user states" do
    # OAuth user without password
    oauth_user = User.new(provider: 'google_oauth2', uid: '123')
    oauth_user.password = nil
    assert_not oauth_user.send(:password_required?)
    
    # OAuth user trying to set password
    oauth_user.password = 'newpassword123'
    assert oauth_user.send(:password_required?)
    
    # Regular user
    regular_user = User.new(provider: nil)
    assert regular_user.send(:password_required?)
  end
end