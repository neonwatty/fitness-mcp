require "test_helper"

class RecentSetsDisplayTest < ActionDispatch::IntegrationTest
  def setup
    # Clear all existing data to avoid test pollution
    SetEntry.destroy_all
    ApiKey.destroy_all
    User.destroy_all
  end

  test "dashboard shows recent sets for logged-in user after API workout logging" do
    # Create a user
    user = User.create!(
      email: "workout@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Create API key for the user
    api_key_value = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key_value)
    api_key_record = user.api_keys.create!(
      name: "Test Workout API Key",
      api_key_hash: key_hash
    )
    
    # Login as the user
    post "/login", params: {
      email: "workout@example.com",
      password: "password123"
    }
    assert_response :redirect
    
    # Visit dashboard - should show no recent sets initially
    get "/dashboard"
    assert_response :success
    assert_select "h2", text: "Recent Sets"
    assert_select ".text-gray-500", text: "No sets logged yet."
    
    # Log a workout set via API using the user's API key
    post "/api/v1/fitness/log_set", 
      params: { exercise: "Deadlift", weight: 225.0, reps: 3 }.to_json,
      headers: {
        "Authorization" => "Bearer #{api_key_value}",
        "Content-Type" => "application/json"
      }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Deadlift", json["set"]["exercise"]
    assert_equal 225.0, json["set"]["weight"]
    assert_equal 3, json["set"]["reps"]
    
    # Refresh dashboard - should now show the recent set
    get "/dashboard"
    assert_response :success
    assert_select "h2", text: "Recent Sets"
    
    # Should no longer show "No sets logged yet"
    assert_select ".text-gray-500", text: "No sets logged yet.", count: 0
    
    # Should show the logged workout in Recent Sets
    assert_select ".bg-gray-50", text: /Deadlift/
    assert_select ".bg-gray-50", text: /3 reps @ 225.0 lbs/
    
    # Verify the set count increased for this specific user
    assert_equal 1, user.reload.set_entries.count
  end
  
  test "dashboard shows recent sets only for logged-in user, not other users" do
    # Create two users
    user1 = User.create!(
      email: "user1@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    user2 = User.create!(
      email: "user2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Create API keys for both users
    api_key1_value = ApiKey.generate_key
    key_hash1 = ApiKey.hash_key(api_key1_value)
    user1.api_keys.create!(name: "User 1 API Key", api_key_hash: key_hash1)
    
    api_key2_value = ApiKey.generate_key
    key_hash2 = ApiKey.hash_key(api_key2_value)
    user2.api_keys.create!(name: "User 2 API Key", api_key_hash: key_hash2)
    
    # User 1 logs a workout using their API key
    post "/api/v1/fitness/log_set", 
      params: { exercise: "User 1 Exercise", weight: 100, reps: 5 }.to_json,
      headers: {
        "Authorization" => "Bearer #{api_key1_value}",
        "Content-Type" => "application/json"
      }
    assert_response :success
    
    # User 2 logs a workout using their API key
    post "/api/v1/fitness/log_set", 
      params: { exercise: "User 2 Exercise", weight: 200, reps: 3 }.to_json,
      headers: {
        "Authorization" => "Bearer #{api_key2_value}",
        "Content-Type" => "application/json"
      }
    assert_response :success
    
    # Login as User 1
    post "/login", params: {
      email: "user1@example.com",
      password: "password123"
    }
    
    # User 1's dashboard should only show their own sets
    get "/dashboard"
    assert_response :success
    assert_select ".bg-gray-50", text: /User 1 Exercise/
    assert_select ".bg-gray-50", text: /User 2 Exercise/, count: 0
    
    # Logout and login as User 2
    delete "/logout"
    post "/login", params: {
      email: "user2@example.com",
      password: "password123"
    }
    
    # User 2's dashboard should only show their own sets
    get "/dashboard"
    assert_response :success
    assert_select ".bg-gray-50", text: /User 2 Exercise/
    assert_select ".bg-gray-50", text: /User 1 Exercise/, count: 0
  end
end