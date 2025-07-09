require "test_helper"

class ApiKeyVisibilityTest < ActionDispatch::IntegrationTest
  def setup
    # Clear existing data
    ApiKey.destroy_all
    User.destroy_all
    
    @user = User.create!(
      email: "visibility@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "API key creation stores both hash and value" do
    # Create API key directly
    api_key_value = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key_value)
    
    api_key_record = @user.api_keys.create!(
      name: "Visibility Test Key",
      api_key_hash: key_hash,
      api_key_value: api_key_value
    )
    
    # Verify both hash and value are stored
    assert_not_nil api_key_record.api_key_hash
    assert_not_nil api_key_record.api_key_value
    assert_equal api_key_value, api_key_record.api_key_value
  end
  
  test "dashboard shows API key with visibility toggle elements" do
    # Create API key first
    api_key_value = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key_value)
    @user.api_keys.create!(
      name: "Dashboard Test Key",
      api_key_hash: key_hash,
      api_key_value: api_key_value
    )
    
    # Login
    post "/login", params: {
      email: "visibility@example.com",
      password: "password123"
    }
    
    # Visit dashboard
    get "/dashboard"
    assert_response :success
    
    # Check that API key display elements are present
    # Note: There are 2 inputs with "api-key-" prefix: one for the actual key and one for the testing interface
    assert_select "input[id^='api-key-']", count: 2
    assert_select "button[onclick*='toggleApiKeyVisibility']", count: 1
    assert_select "button[onclick*='copyApiKey']", count: 1
    
    # Check that the key value is present in the input (but not in the testing interface input)
    assert_select "input[value='#{api_key_value}']", count: 1
  end
  
  test "dashboard handles missing API key values gracefully" do
    # Create API key without value (simulating old data)
    api_key_value = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key_value)
    @user.api_keys.create!(
      name: "Legacy Key",
      api_key_hash: key_hash,
      api_key_value: nil
    )
    
    # Login
    post "/login", params: {
      email: "visibility@example.com",
      password: "password123"
    }
    
    # Visit dashboard
    get "/dashboard"
    assert_response :success
    
    # Check that disabled input is present
    assert_select "input[disabled]", count: 1
    assert_select "input[value*='Key not available']", count: 1
    
    # Check that buttons are disabled
    assert_select "button[disabled][onclick*='toggleApiKeyVisibility']", count: 1
    assert_select "button[disabled][onclick*='copyApiKey']", count: 1
  end
end