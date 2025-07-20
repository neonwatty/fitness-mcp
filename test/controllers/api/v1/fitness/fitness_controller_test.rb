require 'test_helper'

class Api::V1::Fitness::FitnessControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @other_user = create_user
    @other_api_key_record, @other_api_key = create_api_key(user: @other_user)
    
    # Create test data
    @set_entry1 = @user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: 1.hour.ago
    )
    
    @set_entry2 = @user.set_entries.create!(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: 2.hours.ago
    )
    
    @future_assignment = @user.workout_assignments.create!(
      assignment_name: "Future Workout",
      config: '{"exercises": ["push-ups", "Squats"]}',
      scheduled_for: 1.day.from_now
    )
    
    @past_assignment = @user.workout_assignments.create!(
      assignment_name: "Past Workout",
      config: '{"exercises": ["Deadlifts"]}',
      scheduled_for: 1.day.ago
    )
    
    @headers = api_headers(@api_key)
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
    # Delete the sets created in setup
    @user.set_entries.destroy_all
    
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

  # Tests for log_set endpoint
  test "should log set with valid data" do
    post "/api/v1/fitness/log_set", 
         headers: @headers,
         params: {
           exercise: "Overhead Press",
           weight: 95.0,
           reps: 12
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Set logged successfully", json["message"]
    assert_equal "overhead press", json["set"]["exercise"]
    assert_equal 95.0, json["set"]["weight"]
    assert_equal 12, json["set"]["reps"]
    assert json["set"]["timestamp"]
    assert json["set"]["id"]
    
    # Verify it was actually created
    assert_equal 3, @user.set_entries.count
  end
  
  test "should log set with custom timestamp" do
    custom_time = 1.week.ago
    post "/api/v1/fitness/log_set", 
         headers: @headers,
         params: {
           exercise: "Overhead Press",
           weight: 95.0,
           reps: 12,
           timestamp: custom_time
         }
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal custom_time.to_i, Time.parse(json["set"]["timestamp"]).to_i
  end
  
  test "should not log set without exercise" do
    post "/api/v1/fitness/log_set", 
         headers: @headers,
         params: {
           weight: 95.0,
           reps: 12
         }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Exercise is required", json["message"]
  end
  
  test "should not log set without weight" do
    post "/api/v1/fitness/log_set", 
         headers: @headers,
         params: {
           exercise: "Overhead Press",
           reps: 12
         }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Weight is required", json["message"]
  end
  
  test "should not log set without reps" do
    post "/api/v1/fitness/log_set", 
         headers: @headers,
         params: {
           exercise: "Overhead Press",
           weight: 95.0
         }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Reps is required", json["message"]
  end
  
  test "should not log set without API key" do
    post "/api/v1/fitness/log_set", 
         params: {
           exercise: "Overhead Press",
           weight: 95.0,
           reps: 12
         }
    
    assert_response :unauthorized
  end
  
  test "should handle log set validation errors" do
    post "/api/v1/fitness/log_set", 
         headers: @headers,
         params: {
           exercise: "",
           weight: 0,
           reps: 0
         }
    
    # Controller checks for empty exercise first, returning 400
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Exercise is required", json["message"]
  end

  # Tests for history endpoint
  test "should get history" do
    get "/api/v1/fitness/history", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 2, json["history"].length
    
    # Check structure
    set = json["history"].first
    assert set["id"]
    assert set["exercise"]
    assert set["weight"]
    assert set["reps"]
    assert set["timestamp"]
  end
  
  test "should get history filtered by exercise" do
    get "/api/v1/fitness/history", 
        headers: @headers,
        params: { exercise: "Bench Press" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["history"].length
    assert_equal "Bench Press", json["history"].first["exercise"]
  end
  
  test "should get history with limit" do
    get "/api/v1/fitness/history", 
        headers: @headers,
        params: { limit: 1 }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 1, json["history"].length
  end
  
  test "should not get history without API key" do
    get "/api/v1/fitness/history"
    
    assert_response :unauthorized
  end

  # Tests for get_last_set endpoint
  test "should get last set for exercise" do
    get "/api/v1/fitness/get_last_set", 
        headers: @headers,
        params: { exercise: "Bench Press" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Bench Press", json["set"]["exercise"]
    assert_equal 135.0, json["set"]["weight"].to_f
    assert_equal 10, json["set"]["reps"]
    assert json["set"]["timestamp"]
    assert json["set"]["id"]
  end
  
  test "should get last set case insensitive" do
    get "/api/v1/fitness/get_last_set", 
        headers: @headers,
        params: { exercise: "BENCH PRESS" }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Bench Press", json["set"]["exercise"]
  end
  
  test "should handle whitespace in exercise name" do
    get "/api/v1/fitness/get_last_set", 
        headers: @headers,
        params: { exercise: "  Bench Press  " }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Bench Press", json["set"]["exercise"]
  end
  
  test "should not find last set for non-existent exercise" do
    get "/api/v1/fitness/get_last_set", 
        headers: @headers,
        params: { exercise: "Non-existent Exercise" }
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "No sets found", json["message"]
  end
  
  test "should not get last set without exercise" do
    get "/api/v1/fitness/get_last_set", headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Exercise is required", json["message"]
  end
  
  test "should not get last set without API key" do
    get "/api/v1/fitness/get_last_set", params: { exercise: "Bench Press" }
    
    assert_response :unauthorized
  end
end