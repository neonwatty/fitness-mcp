require "test_helper"

class WorkoutAssignmentWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @headers = { 'Authorization' => "Bearer #{@api_key}" }
  end

  test "complete workout assignment and planning workflow" do
    # Step 1: Create multiple workout plans with different configurations
    workout_plans = [
      {
        assignment_name: "Push Day",
        scheduled_for: Date.tomorrow,
        config: {
          exercises: [
            { name: "Bench Press", sets: 3, reps: 10, weight: 135 },
            { name: "Shoulder Press", sets: 3, reps: 8, weight: 95 },
            { name: "Tricep Dips", sets: 3, reps: 12, weight: 0 }
          ],
          rest_time: 90,
          notes: "Focus on form over weight"
        }
      },
      {
        assignment_name: "Pull Day", 
        scheduled_for: Date.tomorrow + 2.days,
        config: {
          exercises: [
            { name: "Pull-ups", sets: 4, reps: 8, weight: 0 },
            { name: "Bent Over Row", sets: 3, reps: 10, weight: 115 },
            { name: "Lat Pulldown", sets: 3, reps: 12, weight: 100 }
          ],
          rest_time: 120,
          notes: "Focus on back engagement"
        }
      },
      {
        assignment_name: "Leg Day",
        scheduled_for: Date.tomorrow + 4.days,
        config: {
          exercises: [
            { name: "Squat", sets: 4, reps: 8, weight: 185 },
            { name: "Deadlift", sets: 3, reps: 5, weight: 225 },
            { name: "Lunges", sets: 3, reps: 12, weight: 0 }
          ],
          rest_time: 180,
          notes: "Warmup thoroughly"
        }
      }
    ]
    
    created_assignments = []
    
    # Create each workout assignment
    workout_plans.each do |plan|
      post "/api/v1/fitness/assign_workout",
        params: plan,
        headers: @headers
      
      assert_response :created
      json = JSON.parse(response.body)
      assert json["success"], "Failed to create assignment: #{json['message']}"
      assert_equal "Workout assigned successfully", json["message"]
      
      assignment = json["assignment"]
      assert assignment["id"]
      assert_equal plan[:assignment_name], assignment["assignment_name"]
      assert_equal plan[:scheduled_for].to_s, Date.parse(assignment["scheduled_for"]).to_s
      
      # Verify config was stored correctly
      stored_config = JSON.parse(assignment["config"])
      assert_equal plan[:config][:exercises].length, stored_config["exercises"].length
      assert_equal plan[:config][:rest_time].to_s, stored_config["rest_time"].to_s
      assert_equal plan[:config][:notes], stored_config["notes"]
      
      created_assignments << assignment
    end
    
    # Verify all assignments were created
    assert_equal 3, @user.workout_assignments.count
    
    # Step 2: Retrieve all workout plans
    get "/api/v1/fitness/plans", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    plans = json["plans"]
    
    assert_equal 3, plans.length
    plan_names = plans.map { |p| p["assignment_name"] }
    assert_includes plan_names, "Push Day"
    assert_includes plan_names, "Pull Day" 
    assert_includes plan_names, "Leg Day"
    
    # Step 3: Execute the first workout (Push Day)
    push_day_assignment = created_assignments.find { |a| a["assignment_name"] == "Push Day" }
    push_day_config = JSON.parse(push_day_assignment["config"])
    
    # Log sets according to the push day plan
    executed_sets = []
    push_day_config["exercises"].each do |exercise|
      exercise["sets"].to_i.times do |set_num|
        # Simulate slight weight/rep variations during execution
        actual_weight = exercise["weight"].to_f + (set_num * 2.5) # Progressive overload
        actual_reps = exercise["reps"].to_i - (set_num) # Fatigue effect
        
        post "/api/v1/fitness/log_set",
          params: {
            exercise: exercise["name"],
            weight: actual_weight,
            reps: actual_reps
          },
          headers: @headers
        
        assert_response :created
        json = JSON.parse(response.body)
        assert json["success"]
        
        executed_sets << {
          exercise: exercise["name"],
          planned_weight: exercise["weight"].to_f,
          actual_weight: actual_weight,
          planned_reps: exercise["reps"].to_i,
          actual_reps: actual_reps
        }
      end
    end
    
    # Verify 9 sets were logged (3 exercises × 3 sets each)
    assert_equal 9, executed_sets.length
    assert_equal 9, @user.set_entries.count
    
    # Step 4: Analyze workout completion vs plan
    get "/api/v1/fitness/history", headers: @headers
    
    assert_response :success
    json = JSON.parse(response.body)
    history = json["history"]
    
    # Group history by exercise
    exercises_completed = history.group_by { |set| set["exercise"] }
    
    push_day_config["exercises"].each do |planned_exercise|
      completed_sets = exercises_completed[planned_exercise["name"]]
      assert_equal planned_exercise["sets"].to_i, completed_sets.length, 
        "Expected #{planned_exercise['sets']} sets for #{planned_exercise['name']}, got #{completed_sets&.length}"
    end
    
    # Step 5: Test assignment validation and error handling
    # Try to create assignment with missing required fields
    post "/api/v1/fitness/assign_workout",
      params: { assignment_name: "Invalid Plan" },
      headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Scheduled for is required", json["message"]
    
    # Try to create assignment without config
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "Another Invalid Plan",
        scheduled_for: Date.tomorrow
      },
      headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Config is required", json["message"]
    
    # Try to create assignment without assignment_name
    post "/api/v1/fitness/assign_workout",
      params: {
        scheduled_for: Date.tomorrow,
        config: { exercises: [] }
      },
      headers: @headers
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Assignment name is required", json["message"]
    
    # Verify no invalid assignments were created
    assert_equal 3, @user.workout_assignments.count
    
    # Step 6: Test scheduling conflicts and date-based filtering
    # Create assignment for same date as existing one
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "Push Day V2",
        scheduled_for: Date.tomorrow, # Same as first Push Day
        config: {
          exercises: [
            { name: "Incline Bench", sets: 3, reps: 10, weight: 115 }
          ]
        }
      },
      headers: @headers
    
    assert_response :created # Should allow multiple assignments per day
    json = JSON.parse(response.body)
    assert json["success"]
    
    # Verify we now have 4 total assignments
    assert_equal 4, @user.workout_assignments.count
    
    # Step 7: Test complex config with nested data
    complex_config = {
      exercises: [
        {
          name: "Compound Superset",
          primary: { name: "Squat", sets: 4, reps: 8, weight: 185 },
          secondary: { name: "Calf Raise", sets: 4, reps: 15, weight: 45 },
          rest_between: 30,
          rest_after: 120
        }
      ],
      warmup: {
        duration: 10,
        exercises: ["Dynamic stretching", "Light cardio"]
      },
      cooldown: {
        duration: 15,
        exercises: ["Static stretching", "Foam rolling"]
      },
      intensity: "moderate",
      estimated_duration: 60
    }
    
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "Complex Workout",
        scheduled_for: Date.tomorrow + 7.days,
        config: complex_config
      },
      headers: @headers
    
    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    
    # Verify complex config was stored and retrieved correctly
    stored_config = JSON.parse(json["assignment"]["config"])
    assert_equal complex_config[:warmup][:duration].to_s, stored_config["warmup"]["duration"].to_s
    assert_equal complex_config[:exercises][0][:primary][:name], 
      stored_config["exercises"][0]["primary"]["name"]
    assert_equal complex_config[:estimated_duration].to_s, stored_config["estimated_duration"].to_s
  end
  
  test "workout assignment workflow with authentication errors" do
    # Test without authentication
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "Test Workout",
        scheduled_for: Date.tomorrow,
        config: { exercises: [] }
      }
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
    
    # Test with invalid API key
    invalid_headers = { 'Authorization' => "Bearer invalid_key_12345" }
    
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "Test Workout",
        scheduled_for: Date.tomorrow,
        config: { exercises: [] }
      },
      headers: invalid_headers
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Missing or invalid API key", json["message"]
    
    # Verify no assignments were created
    assert_equal 0, @user.workout_assignments.count
  end
  
  test "multi-user assignment isolation" do
    # Create a second user
    user2 = create_user(email: "user2@example.com")
    api_key_record2, api_key2 = create_api_key(user: user2)
    headers2 = { 'Authorization' => "Bearer #{api_key2}" }
    
    # Create assignments for both users
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "User 1 Workout",
        scheduled_for: Date.tomorrow,
        config: { exercises: [{ name: "Exercise 1", sets: 3, reps: 10 }] }
      },
      headers: @headers
    
    assert_response :created
    
    post "/api/v1/fitness/assign_workout",
      params: {
        assignment_name: "User 2 Workout", 
        scheduled_for: Date.tomorrow,
        config: { exercises: [{ name: "Exercise 2", sets: 4, reps: 8 }] }
      },
      headers: headers2
    
    assert_response :created
    
    # Verify each user only sees their own assignments
    get "/api/v1/fitness/plans", headers: @headers
    assert_response :success
    json = JSON.parse(response.body)
    user1_plans = json["plans"]
    assert_equal 1, user1_plans.length
    assert_equal "User 1 Workout", user1_plans[0]["assignment_name"]
    
    get "/api/v1/fitness/plans", headers: headers2
    assert_response :success
    json = JSON.parse(response.body)
    user2_plans = json["plans"]
    assert_equal 1, user2_plans.length
    assert_equal "User 2 Workout", user2_plans[0]["assignment_name"]
    
    # Verify database isolation
    assert_equal 1, @user.workout_assignments.count
    assert_equal 1, user2.workout_assignments.count
    assert_equal 2, WorkoutAssignment.count
  end
end