require "test_helper"

class WorkoutLoggingWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @headers = { 'Authorization' => "Bearer #{@api_key}" }
  end

  test "complete workout logging workflow from registration to history analysis" do
    # Step 1: Verify user and API key are properly set up
    assert @user.persisted?
    assert @api_key_record.persisted?
    assert @api_key_record.active?
    
    # Step 2: Log a complete workout session with multiple exercises
    workout_session = [
      { exercise: "Bench Press", sets: [
        { weight: 135, reps: 12 },
        { weight: 155, reps: 10 },
        { weight: 165, reps: 8 }
      ]},
      { exercise: "Squat", sets: [
        { weight: 185, reps: 10 },
        { weight: 205, reps: 8 },
        { weight: 225, reps: 6 }
      ]},
      { exercise: "Deadlift", sets: [
        { weight: 225, reps: 5 },
        { weight: 245, reps: 3 },
        { weight: 265, reps: 1 }
      ]}
    ]
    
    logged_sets = []
    workout_session.each_with_index do |exercise_data, exercise_index|
      exercise_data[:sets].each_with_index do |set_data, set_index|
        # Simulate time progression during workout (more recent timestamps come later)
        timestamp = (45 - (exercise_index * 15) - (set_index * 3)).minutes.ago
        
        post "/api/v1/fitness/log_set",
          params: {
            exercise: exercise_data[:exercise],
            weight: set_data[:weight],
            reps: set_data[:reps],
            timestamp: timestamp.iso8601
          },
          headers: @headers
          
        assert_response :created
        json = JSON.parse(response.body)
        assert json["success"], "Failed to log set: #{json['message']}"
        
        logged_sets << {
          id: json["set"]["id"],
          exercise: json["set"]["exercise"],
          weight: json["set"]["weight"],
          reps: json["set"]["reps"],
          timestamp: json["set"]["timestamp"]
        }
      end
    end
    
    # Verify all 9 sets were logged
    assert_equal 9, logged_sets.length
    assert_equal 9, @user.set_entries.count
    
    # Step 3: Retrieve complete workout history
    get "/api/v1/fitness/history", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    history = json["history"]
    
    # Verify history contains all sets in correct order (most recent first)
    assert_equal 9, history.length
    assert_equal "deadlift", history[0]["exercise"] # Most recent
    assert_equal "bench press", history[8]["exercise"] # Oldest
    
    # Step 4: Test exercise-specific filtering
    get "/api/v1/fitness/history",
      params: { exercise: "squat" },
      headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    squat_history = json["history"]
    
    assert_equal 3, squat_history.length
    squat_history.each do |set|
      assert_equal "squat", set["exercise"]
    end
    
    # Verify progression (heavier weights should be more recent)
    assert squat_history[0]["weight"] > squat_history[1]["weight"]
    assert squat_history[1]["weight"] > squat_history[2]["weight"]
    
    # Step 5: Test limit parameter
    get "/api/v1/fitness/history",
      params: { limit: 5 },
      headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    limited_history = json["history"]
    
    assert_equal 5, limited_history.length
    
    # Step 6: Test combination of exercise filter and limit
    get "/api/v1/fitness/history",
      params: { exercise: "bench press", limit: 2 },
      headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    filtered_limited = json["history"]
    
    assert_equal 2, filtered_limited.length
    filtered_limited.each do |set|
      assert_equal "bench press", set["exercise"]
    end
    
    # Step 7: Verify data integrity across different access methods
    # Check that direct database counts match API responses
    bench_sets_db = @user.set_entries.for_exercise("bench press").count
    squat_sets_db = @user.set_entries.for_exercise("squat").count
    deadlift_sets_db = @user.set_entries.for_exercise("deadlift").count
    
    assert_equal 3, bench_sets_db
    assert_equal 3, squat_sets_db
    assert_equal 3, deadlift_sets_db
    
    # Step 8: Test error handling during workflow
    # Try to log invalid set during session
    post "/api/v1/fitness/log_set",
      params: {
        exercise: "Invalid Exercise",
        weight: -50, # Invalid weight
        reps: 0      # Invalid reps
      },
      headers: @headers
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_includes json["message"], "Weight must be greater than or equal to 0"
    
    # Verify failed set didn't affect existing data
    assert_equal 9, @user.set_entries.count
    
    # Step 9: Test with invalid API key
    invalid_headers = { 'Authorization' => "Bearer invalid_key" }
    
    post "/api/v1/fitness/log_set",
      params: {
        exercise: "Test Exercise",
        weight: 100,
        reps: 10
      },
      headers: invalid_headers
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
  end
  
  test "workflow with bodyweight exercises and zero weights" do
    # Test logging bodyweight exercises (weight = 0)
    bodyweight_exercises = [
      { exercise: "Push-ups", weight: 0, reps: 20 },
      { exercise: "Pull-ups", weight: 0, reps: 8 },
      { exercise: "Dips", weight: 0, reps: 15 }
    ]
    
    bodyweight_exercises.each do |exercise_data|
      post "/api/v1/fitness/log_set",
        params: exercise_data,
        headers: @headers
      
      assert_response :created
      json = JSON.parse(response.body)
      assert json["success"]
      assert_equal 0.0, json["set"]["weight"]
    end
    
    # Verify bodyweight exercises appear in history
    get "/api/v1/fitness/history", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    history = json["history"]
    
    assert_equal 3, history.length
    bodyweight_names = history.map { |set| set["exercise"] }
    assert_includes bodyweight_names, "push-ups"
    assert_includes bodyweight_names, "pull-ups"
    assert_includes bodyweight_names, "dips"
  end
  
  test "large workout session performance and data handling" do
    # Test logging a large number of sets to verify performance
    start_time = Time.current
    
    # Log 50 sets across 10 exercises
    50.times do |i|
      exercise = "Exercise #{(i % 10) + 1}"
      weight = 100 + (i * 2.5)
      reps = 8 + (i % 5)
      
      post "/api/v1/fitness/log_set",
        params: {
          exercise: exercise,
          weight: weight,
          reps: reps
        },
        headers: @headers
      
      assert_response :created
    end
    
    end_time = Time.current
    total_time = end_time - start_time
    
    # Should complete within reasonable time (adjust threshold as needed)
    assert total_time < 30.seconds, "Large workout logging took too long: #{total_time} seconds"
    
    # Verify all sets were logged
    assert_equal 50, @user.set_entries.count
    
    # Test history retrieval performance
    history_start = Time.current
    get "/api/v1/fitness/history", headers: @headers
    history_end = Time.current
    
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 50, json["history"].length
    
    history_time = history_end - history_start
    assert history_time < 5.seconds, "History retrieval took too long: #{history_time} seconds"
  end
end