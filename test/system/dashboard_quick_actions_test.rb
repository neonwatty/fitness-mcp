require "application_system_test_case"

class DashboardQuickActionsTest < ApplicationSystemTestCase
  test "user can log workout set via dashboard button with JavaScript" do
    # Setup: Create user and navigate to dashboard
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    assert_selector "h1", text: "Welcome, #{user.email}"
    
    # Step 1: Create API key through the web interface
    click_button "Create New API Key"
    
    # Handle the prompt for API key name
    page.driver.browser.switch_to.alert.send_keys("Test API Key")
    page.driver.browser.switch_to.alert.accept
    
    # Wait for the API key to be created and alert to appear
    sleep 1
    
    # Accept the success alert that shows the API key
    page.driver.browser.switch_to.alert.accept
    
    # Step 2: The API key should be auto-filled in the input field
    api_key_input = find("#api-key-input")
    assert_not_empty api_key_input.value, "API key should be auto-filled"
    
    # Step 3: Test Log Workout Set functionality
    fill_in "exercise", with: "Bench Press"
    fill_in "weight", with: "185"
    fill_in "reps", with: "8"
    
    # Click the Log Set button - this executes the JavaScript
    click_button "Log Set"
    
    # Wait for API response to appear
    wait_for_api_response
    
    # Verify the API response shows success
    response = get_api_response_json
    assert response["success"], "API should return success"
    assert response["set"].present?, "Response should contain set data"
    assert_equal "bench press", response["set"]["exercise"]
    assert_equal "185.0", response["set"]["weight"]
    assert_equal 8, response["set"]["reps"]
    
    # Step 4: Test Get Last Set functionality  
    fill_in "get-exercise", with: "Bench Press"
    click_button "Get Last Set"
    
    wait_for_api_response
    
    response = get_api_response_json
    assert response["success"], "Get Last Set should return success"
    assert response["set"].present?, "Response should contain set data"
    assert_equal "bench press", response["set"]["exercise"]
    
    # Step 5: Test Get Last N Sets functionality
    fill_in "get-sets-exercise", with: "Bench Press"
    fill_in "sets-limit", with: "3"
    click_button "Get Sets"
    
    wait_for_api_response
    
    response = get_api_response_json
    assert response["success"], "Get Last Sets should return success"
    assert response["sets"].present?, "Response should contain sets array"
    assert_equal 1, response["sets"].length
    assert_equal "bench press", response["sets"][0]["exercise"]
  end

  test "dashboard shows appropriate error messages for invalid API calls" do
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    
    # Create and fill API key
    click_button "Create New API Key"
    page.driver.browser.switch_to.alert.send_keys("Test API Key")
    page.driver.browser.switch_to.alert.accept
    sleep 1
    page.driver.browser.switch_to.alert.accept
    
    # Test 1: Try to log set with missing data
    fill_in "exercise", with: ""
    fill_in "weight", with: "185"
    fill_in "reps", with: "8"
    
    click_button "Log Set"
    
    # Should get browser alert for missing fields
    alert = page.driver.browser.switch_to.alert
    assert_includes alert.text, "Please fill in all fields"
    alert.accept
    
    # Test 2: Try to get last set with missing exercise
    fill_in "get-exercise", with: ""
    click_button "Get Last Set"
    
    alert = page.driver.browser.switch_to.alert
    assert_includes alert.text, "Please enter an exercise name"
    alert.accept
    
    # Test 3: Test with valid data but non-existent exercise
    fill_in "get-exercise", with: "Non-existent Exercise"
    click_button "Get Last Set"
    
    wait_for_api_response
    
    response = get_api_response_json
    assert_not response["success"], "Should return error for non-existent exercise"
    assert_includes response["message"], "No sets found"
  end

  test "dashboard handles invalid API key gracefully" do
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    
    # Manually enter an invalid API key
    fill_in "api-key-input", with: "invalid-api-key-12345"
    
    # Try to log a set
    fill_in "exercise", with: "Bench Press"
    fill_in "weight", with: "185"
    fill_in "reps", with: "8"
    
    click_button "Log Set"
    
    wait_for_api_response
    
    response = get_api_response_json
    assert_not response["success"], "Should return error for invalid API key"
    assert_includes response["message"], "Missing or invalid API key"
  end

  test "API key creation and revocation workflow" do
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    
    # Initially no API keys
    assert_selector "p", text: "No API keys yet. Create one to get started."
    
    # Create first API key
    click_button "Create New API Key"
    page.driver.browser.switch_to.alert.send_keys("First API Key")
    page.driver.browser.switch_to.alert.accept
    sleep 1
    page.driver.browser.switch_to.alert.accept
    
    # Should now show the API key in the list
    assert_selector "span.font-medium", text: "First API Key"
    
    # Create second API key
    click_button "Create New API Key"
    page.driver.browser.switch_to.alert.send_keys("Second API Key")
    page.driver.browser.switch_to.alert.accept
    sleep 1
    page.driver.browser.switch_to.alert.accept
    
    # Should show both API keys
    assert_selector "span.font-medium", text: "First API Key"
    assert_selector "span.font-medium", text: "Second API Key"
    
    # Revoke first API key
    within first(".flex.justify-between.items-center.p-3.bg-gray-50.rounded") do
      click_button "Revoke"
    end
    
    # Confirm revocation
    page.driver.browser.switch_to.alert.accept
    
    # First API key should be removed from the list
    assert_no_selector "span.font-medium", text: "First API Key"
    assert_selector "span.font-medium", text: "Second API Key"
  end

  test "dashboard maintains API key in input field during session" do
    user = create_test_user
    login_as(user)
    
    visit "/dashboard"
    
    # Create API key
    click_button "Create New API Key"
    page.driver.browser.switch_to.alert.send_keys("Session Test Key")
    page.driver.browser.switch_to.alert.accept
    sleep 1
    page.driver.browser.switch_to.alert.accept
    
    # Verify API key is auto-filled
    api_key_value = find("#api-key-input").value
    assert_not_empty api_key_value
    
    # Use the API key for multiple operations
    fill_in "exercise", with: "Squat"
    fill_in "weight", with: "200"
    fill_in "reps", with: "5"
    click_button "Log Set"
    
    wait_for_api_response
    
    # Verify API key is still in the input field
    assert_equal api_key_value, find("#api-key-input").value
    
    # Do another operation
    fill_in "get-exercise", with: "Squat"
    click_button "Get Last Set"
    
    wait_for_api_response
    
    # API key should still be there
    assert_equal api_key_value, find("#api-key-input").value
  end

  private

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