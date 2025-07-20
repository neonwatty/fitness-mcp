require "application_system_test_case"

class OauthSystemTest < ApplicationSystemTestCase
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
  
  test "Google sign-in button is present on login page" do
    visit login_path
    
    # Check that the Google sign-in button is visible
    assert_selector "a[href='/auth/google_oauth2']", text: /Sign in with Google/
    
    # Verify the button has proper styling/classes
    google_button = find("a[href='/auth/google_oauth2']")
    assert google_button.has_css?(".btn-google") || google_button.has_css?(".border-secondary-600")
    
    # Check for Google icon or proper button styling
    assert_selector "a[href='/auth/google_oauth2'] svg", count: 1
  end
  
  test "Google sign-up button is present on register page" do
    visit register_path
    
    # Check that the Google sign-up button is visible
    assert_selector "a[href='/auth/google_oauth2']", text: /Sign up with Google/
    
    # Verify the button has proper styling
    google_button = find("a[href='/auth/google_oauth2']")
    assert google_button.has_css?(".btn-google") || google_button.has_css?(".border-secondary-600")
    
    # Check for Google icon
    assert_selector "a[href='/auth/google_oauth2'] svg", count: 1
  end
  
  test "clicking Google sign-in button initiates OAuth flow" do
    visit login_path
    
    # Click the Google sign-in button
    click_on "Sign in with Google"
    
    # Should redirect to callback which redirects to dashboard
    assert_current_path dashboard_path
    
    # Check success message (may be in dashboard content)
    assert_text "Signed in with Google"
    
    # Verify user is logged in and dashboard shows correct info
    assert_text "Welcome back, OAuth Test User"
    assert_text "Welcome, oauth@example.com"
  end
  
  test "clicking Google sign-up button from register page initiates OAuth flow" do
    visit register_path
    
    # Click the Google sign-up button  
    click_on "Sign up with Google"
    
    # Should redirect to callback which redirects to dashboard
    assert_current_path dashboard_path
    
    # Check success message (may be in dashboard content)
    assert_text "Signed in with Google"
    
    # Verify user account was created and logged in
    assert_text "Welcome back, OAuth Test User"
    assert_text "Welcome, oauth@example.com"
  end
  
  test "OAuth flow creates user with proper dashboard elements" do
    visit login_path
    click_on "Sign in with Google"
    
    # Should be on dashboard
    assert_current_path dashboard_path
    
    # Check key dashboard elements are present
    assert_text "API Key Management"
    assert_text "API Testing Interface"
    assert_text "Create New Key"
    
    # Check navigation shows user is logged in
    assert_text "Welcome, oauth@example.com"
    assert_selector "a", text: "Logout"
  end
  
  test "OAuth user can logout successfully" do
    # Login first
    visit login_path
    click_on "Sign in with Google"
    
    # Verify logged in
    assert_current_path dashboard_path
    assert_text "Welcome, oauth@example.com"
    
    # Logout
    click_on "Logout"
    
    # Should redirect to home page (may go through logout path first)
    visit root_path if current_path != root_path
    assert_text "Logout successful!"
    
    # Navigation should show login/register options
    assert_selector "a", text: "Login"
    assert_selector "a", text: "Get Started"
    assert_no_text "Welcome, oauth@example.com"
  end
  
  test "OAuth buttons maintain consistent styling across pages" do
    # Check login page
    visit login_path
    login_button = find("a[href='/auth/google_oauth2']")
    login_classes = login_button[:class]
    
    # Check register page
    visit register_path
    register_button = find("a[href='/auth/google_oauth2']")
    register_classes = register_button[:class]
    
    # Both should have similar styling classes (allowing for small differences in text)
    # They should both have button-like classes
    assert login_classes.include?("btn") || login_classes.include?("border"), "Login button should have button styling"
    assert register_classes.include?("btn") || register_classes.include?("border"), "Register button should have button styling"
    
    # Both should have Google branding elements
    within(login_button) { assert_selector "svg" }
    within(register_button) { assert_selector "svg" }
  end
  
  test "OAuth flow with existing user account linking" do
    # Create an existing user with the same email
    User.create!(email: 'oauth@example.com', password: 'password123')
    
    # Start OAuth flow
    visit login_path
    click_on "Sign in with Google"
    
    # Should successfully link and login
    assert_current_path dashboard_path
    # Success message appears in dashboard content
    assert_text "Signed in with Google"
    
    # Should still only have one user record
    assert_equal 1, User.where(email: 'oauth@example.com').count
    
    # User should now have OAuth provider linked
    user = User.find_by(email: 'oauth@example.com')
    assert_equal 'google_oauth2', user.provider
    assert_equal '123456789', user.uid
  end
  
  test "mobile responsive OAuth buttons" do
    # Test mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667) # iPhone size
    
    visit login_path
    
    # Google button should still be visible and clickable
    assert_selector "a[href='/auth/google_oauth2']", visible: true
    
    # Button should maintain usability on mobile
    google_button = find("a[href='/auth/google_oauth2']")
    assert google_button.visible?
    
    # Should be able to click it
    click_on "Sign in with Google"
    assert_current_path dashboard_path
  end
end