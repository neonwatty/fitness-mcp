require "application_system_test_case"

class SimplifiedDashboardTest < ApplicationSystemTestCase
  test "user can access dashboard and see API key interface" do
    # Create and login user
    user = create_test_user
    login_as(user)
    
    # Should be on dashboard
    assert_selector "h1", text: "Welcome, #{user.email}"
    assert_selector "h2", text: "API Keys"
    assert_selector "h2", text: "API Testing Interface"
    
    # Should see API key creation button
    assert_selector "button", text: "Create New API Key"
    
    # Should see Quick Actions interface
    assert_selector "h3", text: "Quick Actions"
    assert_selector "input[id='exercise']"
    assert_selector "input[id='weight']"
    assert_selector "input[id='reps']"
    assert_selector "button", text: "Log Set"
    assert_selector "button", text: "Get Last Set"
    assert_selector "button", text: "Get Sets"
  end

  test "dashboard contains correct API endpoint URLs in JavaScript" do
    # This test would catch the endpoint bug by checking the actual HTML
    user = create_test_user
    login_as(user)
    
    # Check that the page source contains the correct API endpoints
    page_source = page.html
    
    # These should be present (correct endpoints)
    assert_includes page_source, "/api/v1/fitness/log_set", "Should call correct log_set endpoint"
    assert_includes page_source, "/api/v1/fitness/get_last_set", "Should call correct get_last_set endpoint"
    assert_includes page_source, "/api/v1/fitness/get_last_sets", "Should call correct get_last_sets endpoint"
    
    # These should NOT be present (incorrect endpoints that caused the bug)
    assert_not_includes page_source, '"/api/v1/log_set"', "Should NOT call wrong log_set endpoint"
    assert_not_includes page_source, '"/api/v1/get_last_set"', "Should NOT call wrong get_last_set endpoint"
    assert_not_includes page_source, '"/api/v1/get_last_sets"', "Should NOT call wrong get_last_sets endpoint"
  end
end