require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def setup
    super
    # Start Rails server for system tests
    Capybara.server = :puma, { Silent: true }
    Capybara.default_max_wait_time = 10
  end

  private

  def login_as(user, password = "password123")
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: password
    click_button "Login"
    
    # Wait for successful login redirect
    assert_current_path "/dashboard"
  end

  def create_test_user(email: "systemtest@example.com", password: "password123")
    User.create!(
      email: email,
      password: password,
      password_confirmation: password
    )
  end

  def create_test_api_key(user:, name: "System Test API Key")
    key = ApiKey.generate_key
    key_hash = ApiKey.hash_key(key)
    api_key_record = user.api_keys.create!(
      name: name,
      api_key_hash: key_hash
    )
    [api_key_record, key]
  end

  def wait_for_api_response
    # Wait for API response to appear in the results panel
    assert_selector "#api-results pre", wait: 10
  end

  def get_api_response_json
    # Extract and parse JSON from the API results panel
    response_text = find("#api-results pre").text
    JSON.parse(response_text)
  end
end