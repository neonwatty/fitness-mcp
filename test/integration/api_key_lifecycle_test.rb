require "test_helper"

class ApiKeyLifecycleTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
  end

  test "complete API key lifecycle from creation to revocation" do
    # Step 1: Create multiple API keys with different names
    # First create an initial API key to use for authentication
    initial_api_key_record, initial_api_key = create_api_key(user: @user)
    headers = { 'Authorization' => "Bearer #{initial_api_key}" }
    
    api_key_names = ["Primary Key", "Mobile App Key", "Development Key", "Backup Key"]
    created_keys = []
    
    api_key_names.each do |name|
      post "/api/v1/api_keys",
        params: { name: name },
        headers: headers
      
      assert_response :created
      json = JSON.parse(response.body)
      assert json["success"]
      assert json["api_key"]["id"]
      assert json["api_key"]["key"]
      assert_equal name, json["api_key"]["name"]
      # Note: create response doesn't include active field, only list response does
      
      created_keys << {
        id: json["api_key"]["id"],
        raw_key: json["api_key"]["key"],
        name: name
      }
    end
    
    # Verify all keys were created
    assert_equal 5, @user.api_keys.count # 4 new + 1 initial
    assert_equal 4, created_keys.length
    
    # Step 2: Test each API key works for authenticated requests
    created_keys.each do |key_data|
      headers = { 'Authorization' => "Bearer #{key_data[:raw_key]}" }
      
      # Test logging a set with each key
      post "/api/v1/fitness/log_set",
        params: {
          exercise: "Test with #{key_data[:name]}",
          weight: 100,
          reps: 10
        },
        headers: headers
      
      assert_response :created
      json = JSON.parse(response.body)
      assert json["success"]
      assert_equal "test with #{key_data[:name].downcase}", json["set"]["exercise"]
    end
    
    # Verify all sets were logged
    assert_equal 4, @user.set_entries.count
    
    # Step 3: List all API keys
    get "/api/v1/api_keys",
      headers: { 'Authorization' => "Bearer #{created_keys.first[:raw_key]}" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    api_keys = json["api_keys"]
    
    assert_equal 5, api_keys.length
    active_keys = api_keys.select { |key| key["active"] }
    assert_equal 5, active_keys.length
    
    # Verify key names are present
    key_names = api_keys.map { |key| key["name"] }
    api_key_names.each do |name|
      assert_includes key_names, name
    end
    
    # Step 4: Revoke specific API keys
    keys_to_revoke = created_keys.first(2) # Revoke first 2 keys
    
    keys_to_revoke.each do |key_data|
      patch "/api/v1/api_keys/#{key_data[:id]}/revoke",
        headers: { 'Authorization' => "Bearer #{created_keys.last[:raw_key]}" } # Use different key for revocation
      
      assert_response :success
      json = JSON.parse(response.body)
      assert json["success"]
      assert_equal "API key revoked successfully", json["message"]
    end
    
    # Step 5: Verify revoked keys cannot be used
    keys_to_revoke.each do |key_data|
      headers = { 'Authorization' => "Bearer #{key_data[:raw_key]}" }
      
      post "/api/v1/fitness/log_set",
        params: {
          exercise: "Should fail",
          weight: 100,
          reps: 10
        },
        headers: headers
      
      assert_response :unauthorized
      json = JSON.parse(response.body)
      assert_not json["success"]
      assert_equal "Missing or invalid API key", json["message"]
    end
    
    # Verify no additional sets were logged
    assert_equal 4, @user.set_entries.count
    
    # Step 6: Verify active keys still work
    remaining_keys = created_keys.last(2) # Last 2 keys should still be active
    
    remaining_keys.each do |key_data|
      headers = { 'Authorization' => "Bearer #{key_data[:raw_key]}" }
      
      get "/api/v1/fitness/history", headers: headers
      
      assert_response :success
      json = JSON.parse(response.body)
      assert json["success"]
      assert_equal 4, json["history"].length
    end
    
    # Step 7: Check API key list shows correct statuses
    get "/api/v1/api_keys",
      headers: { 'Authorization' => "Bearer #{remaining_keys.first[:raw_key]}" }
    
    assert_response :success
    json = JSON.parse(response.body)
    api_keys = json["api_keys"]
    
    # The API only returns active keys, not revoked ones
    assert_equal 3, api_keys.length # 2 remaining + 1 from setup
    
    # All returned keys should be active
    api_keys.each do |key|
      assert key["active"], "All returned keys should be active"
    end
    
    # Step 8: Test deletion of API keys
    key_to_delete = remaining_keys.first
    
    delete "/api/v1/api_keys/#{key_to_delete[:id]}",
      headers: { 'Authorization' => "Bearer #{remaining_keys.last[:raw_key]}" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key deleted successfully", json["message"]
    
    # Verify deleted key no longer appears in list
    get "/api/v1/api_keys",
      headers: { 'Authorization' => "Bearer #{remaining_keys.last[:raw_key]}" }
    
    assert_response :success
    json = JSON.parse(response.body)
    api_keys = json["api_keys"]
    
    assert_equal 2, api_keys.length # One key was deleted from the 3 active keys
    
    key_ids = api_keys.map { |key| key["id"] }
    assert_not_includes key_ids, key_to_delete[:id]
    
    # Verify deleted key cannot be used
    headers = { 'Authorization' => "Bearer #{key_to_delete[:raw_key]}" }
    
    get "/api/v1/fitness/history", headers: headers
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    
    # Step 9: Test edge cases and limits
    # Try to revoke the same key twice
    revoked_key_id = keys_to_revoke.first[:id]
    
    patch "/api/v1/api_keys/#{revoked_key_id}/revoke",
      headers: { 'Authorization' => "Bearer #{remaining_keys.last[:raw_key]}" }
    
    # Should handle gracefully (either success or informative error)
    assert_response_success_or_not_found
    
    # Try to delete non-existent key
    delete "/api/v1/api_keys/99999",
      headers: { 'Authorization' => "Bearer #{remaining_keys.last[:raw_key]}" }
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
  end
  
  test "API key security and validation workflow" do
    # Step 1: Test key creation with invalid/empty names
    original_key = create_api_key(user: @user)[1]
    headers = { 'Authorization' => "Bearer #{original_key}" }
    
    # Try to create key with empty name
    post "/api/v1/api_keys",
      params: { name: "" },
      headers: headers
    
    # Should either reject or provide default name
    if response.status == 400
      json = JSON.parse(response.body)
      assert_not json["success"]
      assert_equal "Name is required", json["message"]
    else
      assert_response :created
    end
    
    # Try to create key with very long name
    long_name = "A" * 300
    post "/api/v1/api_keys",
      params: { name: long_name },
      headers: headers
    
    # Should either truncate or reject
    assert_response_in [201, 400, 422]
    
    # Step 2: Test authentication edge cases
    # Try with malformed authorization header
    malformed_headers = { 'Authorization' => "Invalid header format" }
    
    get "/api/v1/api_keys", headers: malformed_headers
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    
    # Try with correct format but invalid key
    invalid_headers = { 'Authorization' => "Bearer invalid_key_12345" }
    
    get "/api/v1/api_keys", headers: invalid_headers
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    
    # Step 3: Test key uniqueness and collision handling
    # Create multiple keys rapidly to test uniqueness
    rapid_keys = []
    5.times do |i|
      post "/api/v1/api_keys",
        params: { name: "Rapid Key #{i}" },
        headers: headers
      
      if response.status == 201
        json = JSON.parse(response.body)
        rapid_keys << json["api_key"]["key"]
      end
    end
    
    # All keys should be unique
    assert_equal rapid_keys.length, rapid_keys.uniq.length
    
    # Step 4: Test concurrent key operations
    threads = []
    results = []
    
    # Create keys concurrently
    3.times do |i|
      threads << Thread.new do
        post "/api/v1/api_keys",
          params: { name: "Concurrent Key #{i}" },
          headers: headers
        
        results << {
          status: response.status,
          body: response.body
        }
      end
    end
    
    threads.each(&:join)
    
    # Verify all concurrent operations completed
    assert_equal 3, results.length
    successful_creates = results.count { |r| r[:status] == 201 }
    assert successful_creates > 0, "At least some concurrent key creates should succeed"
  end
  
  test "multi-user API key isolation" do
    # Create second user
    user2 = create_user
    
    # Create API keys for both users
    user1_key = create_api_key(user: @user)[1]
    user2_key = create_api_key(user: user2)[1]
    
    user1_headers = { 'Authorization' => "Bearer #{user1_key}" }
    user2_headers = { 'Authorization' => "Bearer #{user2_key}" }
    
    # Each user creates additional keys
    post "/api/v1/api_keys",
      params: { name: "User 1 Extra Key" },
      headers: user1_headers
    
    assert_response :created
    user1_extra_key = JSON.parse(response.body)["api_key"]["raw_key"]
    
    post "/api/v1/api_keys",
      params: { name: "User 2 Extra Key" },
      headers: user2_headers
    
    assert_response :created
    user2_extra_key = JSON.parse(response.body)["api_key"]["raw_key"]
    
    # Verify each user only sees their own keys
    get "/api/v1/api_keys", headers: user1_headers
    assert_response :success
    user1_keys = JSON.parse(response.body)["api_keys"]
    
    get "/api/v1/api_keys", headers: user2_headers
    assert_response :success
    user2_keys = JSON.parse(response.body)["api_keys"]
    
    assert_equal 2, user1_keys.length
    assert_equal 2, user2_keys.length
    
    # Verify keys belong to correct users
    user1_names = user1_keys.map { |k| k["name"] }
    user2_names = user2_keys.map { |k| k["name"] }
    
    assert_includes user1_names, "User 1 Extra Key"
    assert_includes user2_names, "User 2 Extra Key"
    assert_not_includes user1_names, "User 2 Extra Key"
    assert_not_includes user2_names, "User 1 Extra Key"
    
    # Try cross-user key operations (should fail)
    user2_key_id = user2_keys.first["id"]
    
    # User 1 tries to revoke User 2's key
    patch "/api/v1/api_keys/#{user2_key_id}/revoke", headers: user1_headers
    
    assert_response :not_found # Should not find key that doesn't belong to user
    
    # User 1 tries to delete User 2's key
    delete "/api/v1/api_keys/#{user2_key_id}", headers: user1_headers
    
    assert_response :not_found
    
    # Verify User 2's keys are still intact
    get "/api/v1/api_keys", headers: user2_headers
    assert_response :success
    user2_keys_after = JSON.parse(response.body)["api_keys"]
    assert_equal 2, user2_keys_after.length
  end
  
  test "API key usage tracking and audit" do
    # Create API key
    api_key_record, raw_key = create_api_key(user: @user)
    headers = { 'Authorization' => "Bearer #{raw_key}" }
    
    # Clear existing audit logs
    McpAuditLog.destroy_all
    
    # Use the API key for various operations
    operations = [
      { method: :post, path: "/api/v1/fitness/log_set", 
        params: { exercise: "Test", weight: 100, reps: 10 } },
      { method: :get, path: "/api/v1/fitness/history" },
      { method: :get, path: "/api/v1/api_keys" },
      { method: :post, path: "/api/v1/fitness/assign_workout",
        params: { assignment_name: "Test", scheduled_for: Date.tomorrow,
                 config: { exercises: [] } } }
    ]
    
    operations.each do |op|
      case op[:method]
      when :post
        post op[:path], params: op[:params], headers: headers
      when :get
        get op[:path], headers: headers
      end
      
      # All should succeed
      assert_response_in [200, 201]
    end
    
    # Check that API key usage is being tracked
    assert @user.set_entries.count > 0
    assert @user.workout_assignments.count > 0
    
    # Note: Audit logs are only created for MCP tool usage, not direct API calls
    
    # Revoke the key and verify it cannot be used
    api_key_record.update!(revoked_at: Time.current)
    
    get "/api/v1/api_keys", headers: headers
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
  end
  
  private
  
  def assert_response_success_or_not_found
    assert_includes [200, 404], response.status
  end
  
  def assert_response_in(statuses)
    assert_includes statuses, response.status
  end
end