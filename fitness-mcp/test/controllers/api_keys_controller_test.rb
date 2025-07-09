require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(email: "test@example.com", password: "password123")
  end

  test "should create API key when logged in" do
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    post "/api_keys", params: {
      api_key: { name: "Test API Key" }
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key created successfully", json["message"]
    assert json["api_key"].present?
    assert_equal "Test API Key", json["api_key"]["name"]
    assert json["api_key"]["id"].present?
    assert json["api_key"]["created_at"].present?
    assert json["api_key"]["key"].present?
    assert_equal 32, json["api_key"]["key"].length
  end

  test "should not create API key without login" do
    post "/api_keys", params: {
      api_key: { name: "Test API Key" }
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Please log in first", json["message"]
  end

  test "should not create API key without name" do
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    post "/api_keys", params: {
      api_key: { name: "" }
    }
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert json["errors"].present?
  end

  test "should revoke API key when logged in" do
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    # Create an API key first
    api_key, _ = create_api_key(user: @user, name: "Test API Key")
    
    patch "/api_keys/#{api_key.id}/revoke"
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key revoked successfully", json["message"]
    
    # Verify it's revoked
    api_key.reload
    assert_not_nil api_key.revoked_at
  end

  test "should not revoke API key without login" do
    api_key, _ = create_api_key(user: @user, name: "Test API Key")
    
    patch "/api_keys/#{api_key.id}/revoke"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Please log in first", json["message"]
  end

  test "should not revoke non-existent API key" do
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    patch "/api_keys/999999/revoke"
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API key not found", json["message"]
  end

  test "should not revoke other user's API key" do
    other_user = create_user(email: "other@example.com", password: "password123")
    other_api_key, _ = create_api_key(user: other_user, name: "Other API Key")
    
    # Login as first user
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    patch "/api_keys/#{other_api_key.id}/revoke"
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API key not found", json["message"]
  end

  test "should delete API key when logged in" do
    # Login first
    post "/login", params: {
      email: "test@example.com",
      password: "password123"
    }
    
    # Create an API key first
    api_key, _ = create_api_key(user: @user, name: "Test API Key")
    
    delete "/api_keys/#{api_key.id}"
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key deleted successfully", json["message"]
    
    # Verify it's deleted
    assert_raises(ActiveRecord::RecordNotFound) do
      api_key.reload
    end
  end

  test "should not delete API key without login" do
    api_key, _ = create_api_key(user: @user, name: "Test API Key")
    
    delete "/api_keys/#{api_key.id}"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Please log in first", json["message"]
  end
end