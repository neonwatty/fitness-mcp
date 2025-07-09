require "test_helper"

class ApiKeysTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @user_api_key, @raw_key = create_api_key(user: @user)
  end

  test "should create api key with valid authentication" do
    post "/api/v1/api_keys", 
         params: { name: "Test API Key" },
         headers: api_headers(@raw_key)
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API Key created successfully", json["message"]
    assert json["api_key"].present?
    assert_equal "Test API Key", json["api_key"]["name"]
    assert json["api_key"]["key"].present?
    assert_equal 32, json["api_key"]["key"].length
  end

  test "should not create api key without authentication" do
    post "/api/v1/api_keys", params: { name: "Test API Key" }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "should not create api key with invalid authentication" do
    post "/api/v1/api_keys", 
         params: { name: "Test API Key" },
         headers: api_headers("invalid_key")
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "should not create api key without name" do
    post "/api/v1/api_keys", 
         params: {},
         headers: api_headers(@raw_key)
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Name is required", json["message"]
  end

  test "should list user api keys" do
    get "/api/v1/api_keys", headers: api_headers(@raw_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["api_keys"].present?
    assert_equal 1, json["api_keys"].length
    assert_equal @user_api_key.name, json["api_keys"][0]["name"]
    assert_not_includes json["api_keys"][0], "api_key_hash"
  end

  test "should not list api keys without authentication" do
    get "/api/v1/api_keys"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "should revoke api key" do
    delete "/api/v1/api_keys/#{@user_api_key.id}", headers: api_headers(@raw_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "API key deleted successfully", json["message"]
    
    assert_raises(ActiveRecord::RecordNotFound) do
      @user_api_key.reload
    end
  end

  test "should not revoke api key without authentication" do
    delete "/api/v1/api_keys/#{@user_api_key.id}"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "should not revoke other user's api key" do
    other_user = create_user(email: "other@example.com")
    other_api_key, _ = create_api_key(user: other_user)
    
    delete "/api/v1/api_keys/#{other_api_key.id}", headers: api_headers(@raw_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API Key not found", json["message"]
  end

  test "should not revoke non-existent api key" do
    delete "/api/v1/api_keys/999999", headers: api_headers(@raw_key)
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "API Key not found", json["message"]
  end
end