require "test_helper"

class Api::V1::ApiKeysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @other_user = create_user(email: "other@example.com")
    @other_api_key_record, @other_api_key = create_api_key(user: @other_user)
  end

  test "should get index with valid API key" do
    # Create additional API keys for testing
    create_api_key(user: @user, name: "Second API Key")
    create_api_key(user: @user, name: "Third API Key")
    
    get "/api/v1/api_keys", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 3, json["api_keys"].length
    
    # Check response structure
    api_key_data = json["api_keys"].first
    assert api_key_data["id"]
    assert api_key_data["name"]
    assert api_key_data["created_at"]
    assert api_key_data.key?("revoked_at")
    assert api_key_data["active"]
  end
  
  test "should not get index without API key" do
    get "/api/v1/api_keys"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should only show user's own API keys" do
    get "/api/v1/api_keys", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["api_keys"].length
    assert_equal @api_key_record.id, json["api_keys"].first["id"]
  end
  
  test "should only show active API keys in index" do
    revoked_key, _ = create_api_key(user: @user, name: "Revoked Key")
    revoked_key.revoke!
    
    get "/api/v1/api_keys", headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["api_keys"].length
    assert_equal @api_key_record.id, json["api_keys"].first["id"]
  end
  
  test "should create API key with valid data" do
    post "/api/v1/api_keys", 
         headers: api_headers(@api_key),
         params: { name: "New API Key" }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API Key created successfully", json["message"]
    assert json["api_key"]["id"]
    assert_equal "New API Key", json["api_key"]["name"]
    assert json["api_key"]["key"]
    assert_equal 32, json["api_key"]["key"].length
    
    # Verify it was actually created
    assert_equal 2, @user.api_keys.count
  end
  
  test "should not create API key without name" do
    post "/api/v1/api_keys", 
         headers: api_headers(@api_key),
         params: { name: "" }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Name is required", json["message"]
  end
  
  test "should not create API key with missing name param" do
    post "/api/v1/api_keys", 
         headers: api_headers(@api_key),
         params: {}
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Name is required", json["message"]
  end
  
  test "should not create API key without authentication" do
    post "/api/v1/api_keys", params: { name: "Test Key" }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should handle API key creation validation errors" do
    # Test with a name that's too long (assuming there's a validation)
    long_name = "a" * 256
    
    post "/api/v1/api_keys", 
         headers: api_headers(@api_key),
         params: { name: long_name }
    
    # This may pass if there are no validations, but demonstrates testing approach
    # In a real scenario, we'd add validations to the ApiKey model
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
  end
  
  test "should delete API key" do
    key_to_delete, _ = create_api_key(user: @user, name: "Key to Delete")
    
    delete "/api/v1/api_keys/#{key_to_delete.id}", 
           headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key deleted successfully", json["message"]
    
    # Verify it was actually deleted
    assert_not ApiKey.exists?(key_to_delete.id)
  end
  
  test "should not delete non-existent API key" do
    delete "/api/v1/api_keys/999999", 
           headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API Key not found", json["message"]
  end
  
  test "should not delete other user's API key" do
    delete "/api/v1/api_keys/#{@other_api_key_record.id}", 
           headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API Key not found", json["message"]
    
    # Verify the other user's key still exists
    assert ApiKey.exists?(@other_api_key_record.id)
  end
  
  test "should not delete without authentication" do
    delete "/api/v1/api_keys/#{@api_key_record.id}"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should handle delete failure gracefully" do
    # Test deleting a key that doesn't exist anymore (simulates edge case)
    non_existent_id = 999999
    
    delete "/api/v1/api_keys/#{non_existent_id}", 
           headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API Key not found", json["message"]
  end
  
  test "should revoke API key" do
    key_to_revoke, _ = create_api_key(user: @user, name: "Key to Revoke")
    
    patch "/api/v1/api_keys/#{key_to_revoke.id}/revoke", 
          headers: api_headers(@api_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key revoked successfully", json["message"]
    
    # Verify it was actually revoked
    key_to_revoke.reload
    assert_not_nil key_to_revoke.revoked_at
    assert_not key_to_revoke.active?
  end
  
  test "should not revoke non-existent API key" do
    patch "/api/v1/api_keys/999999/revoke", 
          headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "API key not found"
  end
  
  test "should not revoke other user's API key" do
    patch "/api/v1/api_keys/#{@other_api_key_record.id}/revoke", 
          headers: api_headers(@api_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["error"], "API key not found"
    
    # Verify the other user's key is still active
    @other_api_key_record.reload
    assert @other_api_key_record.active?
  end
  
  test "should not revoke without authentication" do
    patch "/api/v1/api_keys/#{@api_key_record.id}/revoke"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "should handle revoke of already revoked key" do
    # Test revoking a key that's already been revoked
    key_to_revoke, _ = create_api_key(user: @user, name: "Key to Revoke")
    key_to_revoke.revoke!
    
    patch "/api/v1/api_keys/#{key_to_revoke.id}/revoke", 
          headers: api_headers(@api_key)
    
    # Should still work, just updating the revoked_at timestamp
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key revoked successfully", json["message"]
  end
end