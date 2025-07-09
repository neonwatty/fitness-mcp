require "test_helper"

class FitnessApiTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @user_api_key, @raw_key = create_api_key(user: @user)
  end

  test "should log set with valid data" do
    post "/api/v1/fitness/log_set", 
         params: {
           exercise: "Bench Press",
           weight: 135.0,
           reps: 10
         },
         headers: api_headers(@raw_key)
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Set logged successfully", json["message"]
    assert json["set"].present?
    assert_equal "Bench Press", json["set"]["exercise"]
    assert_equal 135.0, json["set"]["weight"]
    assert_equal 10, json["set"]["reps"]
  end

  test "should not log set without authentication" do
    post "/api/v1/fitness/log_set", params: {
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "should not log set with missing parameters" do
    post "/api/v1/fitness/log_set", 
         params: { exercise: "Bench Press" },
         headers: api_headers(@raw_key)
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["message"], "Weight is required"
  end

  test "should not log set with invalid data" do
    post "/api/v1/fitness/log_set", 
         params: {
           exercise: "Bench Press",
           weight: -10.0,
           reps: 0
         },
         headers: api_headers(@raw_key)
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["message"], "Weight must be greater than 0"
  end

  test "should get workout history" do
    @user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: 1.hour.ago
    )
    @user.set_entries.create!(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: 30.minutes.ago
    )
    
    get "/api/v1/fitness/history", headers: api_headers(@raw_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["history"].present?
    assert_equal 2, json["history"].length
    assert_equal "Squat", json["history"][0]["exercise"]
    assert_equal "Bench Press", json["history"][1]["exercise"]
  end

  test "should filter workout history by exercise" do
    @user.set_entries.create!(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: 1.hour.ago
    )
    @user.set_entries.create!(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: 30.minutes.ago
    )
    
    get "/api/v1/fitness/history", 
        params: { exercise: "Bench Press" },
        headers: api_headers(@raw_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["history"].present?
    assert_equal 1, json["history"].length
    assert_equal "Bench Press", json["history"][0]["exercise"]
  end

  test "should limit workout history results" do
    5.times do |i|
      @user.set_entries.create!(
        exercise: "Bench Press",
        weight: 135.0,
        reps: 10,
        timestamp: i.hours.ago
      )
    end
    
    get "/api/v1/fitness/history", 
        params: { limit: 3 },
        headers: api_headers(@raw_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["history"].present?
    assert_equal 3, json["history"].length
  end

  test "should create workout plan" do
    post "/api/v1/fitness/create_plan", 
         params: {
           assignment_name: "Push Day",
           scheduled_for: (Time.current + 1.day).iso8601,
           exercises: ["Bench Press", "Shoulder Press", "Tricep Dips"]
         },
         headers: api_headers(@raw_key)
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "Workout plan created successfully", json["message"]
    assert json["plan"].present?
    assert_equal "Push Day", json["plan"]["assignment_name"]
    
    config = JSON.parse(json["plan"]["config"])
    assert_equal ["Bench Press", "Shoulder Press", "Tricep Dips"], config["exercises"]
  end

  test "should not create workout plan without authentication" do
    post "/api/v1/fitness/create_plan", params: {
      assignment_name: "Push Day",
      scheduled_for: (Time.current + 1.day).iso8601,
      exercises: ["Bench Press"]
    }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end

  test "should not create workout plan with missing parameters" do
    post "/api/v1/fitness/create_plan", 
         params: { assignment_name: "Push Day" },
         headers: api_headers(@raw_key)
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["message"], "Scheduled for is required"
  end

  test "should get workout plans" do
    @user.workout_assignments.create!(
      assignment_name: "Push Day",
      scheduled_for: Time.current + 1.day,
      config: { exercises: ["Bench Press"] }.to_json
    )
    @user.workout_assignments.create!(
      assignment_name: "Pull Day",
      scheduled_for: Time.current + 2.days,
      config: { exercises: ["Pull Ups"] }.to_json
    )
    
    get "/api/v1/fitness/plans", headers: api_headers(@raw_key)
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["plans"].present?
    assert_equal 2, json["plans"].length
    assert_equal "Push Day", json["plans"][0]["assignment_name"]
    assert_equal "Pull Day", json["plans"][1]["assignment_name"]
  end

  test "should not get workout plans without authentication" do
    get "/api/v1/fitness/plans"
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
end