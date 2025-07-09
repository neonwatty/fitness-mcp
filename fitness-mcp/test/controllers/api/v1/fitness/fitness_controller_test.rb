require 'test_helper'

class Api::V1::Fitness::FitnessControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Create a valid API key
    api_key_value = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key_value)
    
    @api_key = @user.api_keys.create!(
      name: "Test Key",
      api_key_hash: key_hash,
      api_key_value: api_key_value
    )
    
    @headers = { 'Authorization' => "Bearer #{api_key_value}" }
  end

  test "should get recent sets regardless of exercise" do
    # Create some test data
    @user.set_entries.create!(exercise: "bench press", weight: 185.0, reps: 8, timestamp: 1.hour.ago)
    @user.set_entries.create!(exercise: "squat", weight: 225.0, reps: 5, timestamp: 30.minutes.ago)
    @user.set_entries.create!(exercise: "deadlift", weight: 315.0, reps: 3, timestamp: 10.minutes.ago)
    
    get "/api/v1/fitness/get_recent_sets?limit=2", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 2, json["sets"].length
    
    # Should be ordered by most recent first
    assert_equal "deadlift", json["sets"][0]["exercise"]
    assert_equal "squat", json["sets"][1]["exercise"]
  end
  
  test "should get recent sets with default limit" do
    # Create 15 sets to test default limit
    15.times do |i|
      @user.set_entries.create!(
        exercise: "exercise_#{i}", 
        weight: 100.0, 
        reps: 10, 
        timestamp: (15 - i).minutes.ago
      )
    end
    
    get "/api/v1/fitness/get_recent_sets", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 10, json["sets"].length  # Default limit should be 10
  end
  
  test "should get recent sets with custom limit" do
    5.times do |i|
      @user.set_entries.create!(
        exercise: "exercise_#{i}", 
        weight: 100.0, 
        reps: 10, 
        timestamp: (5 - i).minutes.ago
      )
    end
    
    get "/api/v1/fitness/get_recent_sets?limit=3", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 3, json["sets"].length
  end
  
  test "should return empty array when no sets exist" do
    get "/api/v1/fitness/get_recent_sets", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal [], json["sets"]
  end
  
  test "should require authentication for get_recent_sets" do
    get "/api/v1/fitness/get_recent_sets"
    
    assert_response :unauthorized
  end
end