require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = create_user
    api_key = user.api_keys.build(
      name: "Test API Key",
      api_key_hash: ApiKey.hash_key("test_key_123")
    )
    assert api_key.valid?
  end

  test "should require user_id" do
    api_key = ApiKey.new(
      name: "Test API Key",
      api_key_hash: ApiKey.hash_key("test_key_123")
    )
    assert_not api_key.valid?
    assert_includes api_key.errors[:user], "must exist"
  end

  test "should belong to user" do
    user = create_user
    api_key, _ = create_api_key(user: user)
    assert_equal user, api_key.user
  end

  test "should generate key" do
    key = ApiKey.generate_key
    assert key.is_a?(String)
    assert_equal 32, key.length
    assert_match(/\A[a-zA-Z0-9]{32}\z/, key)
  end

  test "should hash key consistently" do
    key = "test_key_123"
    hash1 = ApiKey.hash_key(key)
    hash2 = ApiKey.hash_key(key)
    assert_equal hash1, hash2
    assert_equal 64, hash1.length
  end

  test "should find by key" do
    user = create_user
    api_key_record, raw_key = create_api_key(user: user)
    
    found_api_key = ApiKey.find_by_key(raw_key)
    assert_equal api_key_record, found_api_key
  end

  test "should return nil for invalid key" do
    found_api_key = ApiKey.find_by_key("invalid_key")
    assert_nil found_api_key
  end

  test "should return nil for revoked key" do
    user = create_user
    api_key_record, raw_key = create_api_key(user: user)
    api_key_record.update!(revoked_at: Time.current)
    
    found_api_key = ApiKey.find_by_key(raw_key)
    assert_nil found_api_key
  end

  test "should check if active" do
    user = create_user
    api_key_record, _ = create_api_key(user: user)
    
    assert api_key_record.active?
    
    api_key_record.update!(revoked_at: Time.current)
    assert_not api_key_record.active?
  end

  test "should revoke key" do
    user = create_user
    api_key_record, _ = create_api_key(user: user)
    
    assert api_key_record.active?
    api_key_record.revoke!
    assert_not api_key_record.active?
    assert_not_nil api_key_record.revoked_at
  end

  test "should not find revoked keys in active scope" do
    user = create_user
    active_key, _ = create_api_key(user: user, name: "Active Key")
    revoked_key, _ = create_api_key(user: user, name: "Revoked Key")
    revoked_key.revoke!
    
    active_keys = ApiKey.active
    assert_includes active_keys, active_key
    assert_not_includes active_keys, revoked_key
  end
end
