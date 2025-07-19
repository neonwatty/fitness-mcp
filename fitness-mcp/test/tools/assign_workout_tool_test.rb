require "test_helper"

class AssignWorkoutToolTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @tool = AssignWorkoutTool.new
    
    # Mock the API key for the tool
    @tool.instance_variable_set(:@api_key, @api_key)
  end

  test "should create workout assignment with valid data" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 },
      { name: "Squat", sets: 4, reps: 8, weight: 185.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Upper Body Workout",
      exercises: exercises,
      scheduled_for: "2024-01-15T10:00:00Z"
    )
    
    assert result[:success]
    assert_equal "Upper Body Workout", result[:workout_assignment][:assignment_name]
    assert_equal 2, result[:workout_assignment][:exercises].length
    assert result[:workout_assignment][:scheduled_for]
    assert_includes result[:message], "Successfully created workout assignment"
    assert_includes result[:message], "scheduled for"
    
    # Verify it was actually created in the database
    assignment = @user.workout_assignments.last
    assert_equal "Upper Body Workout", assignment.assignment_name
    assert_equal Time.parse("2024-01-15T10:00:00Z"), assignment.scheduled_for
  end
  
  test "should create workout assignment without scheduled_for" do
    exercises = [
      { name: "Deadlift", sets: 3, reps: 5, weight: 225.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Quick Workout",
      exercises: exercises
    )
    
    assert result[:success]
    assert_equal "Quick Workout", result[:workout_assignment][:assignment_name]
    assert_nil result[:workout_assignment][:scheduled_for]
    assert_not_includes result[:message], "scheduled for"
    
    # Verify scheduled_for is nil in database
    assignment = @user.workout_assignments.last
    assert_nil assignment.scheduled_for
  end
  
  test "should normalize exercise names to lowercase" do
    exercises = [
      { name: "  BENCH PRESS  ", sets: 3, reps: 10, weight: 135.0 },
      { name: "Squat", sets: 4, reps: 8, weight: 185.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Test Workout",
      exercises: exercises
    )
    
    assert result[:success]
    normalized_exercises = result[:workout_assignment][:exercises]
    assert_equal "bench press", normalized_exercises[0][:name]
    assert_equal "squat", normalized_exercises[1][:name]
  end
  
  test "should handle string keys in exercises" do
    exercises = [
      { "name" => "Bench Press", "sets" => 3, "reps" => 10, "weight" => 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "String Keys Workout",
      exercises: exercises
    )
    
    assert result[:success]
    exercise = result[:workout_assignment][:exercises][0]
    assert_equal "bench press", exercise[:name]
    assert_equal 3, exercise[:sets]
    assert_equal 10, exercise[:reps]
    assert_equal 135.0, exercise[:weight]
  end
  
  test "should handle symbol keys in exercises" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Symbol Keys Workout",
      exercises: exercises
    )
    
    assert result[:success]
    exercise = result[:workout_assignment][:exercises][0]
    assert_equal "bench press", exercise[:name]
    assert_equal 3, exercise[:sets]
    assert_equal 10, exercise[:reps]
    assert_equal 135.0, exercise[:weight]
  end
  
  test "should handle mixed string and symbol keys" do
    exercises = [
      { "name" => "Bench Press", sets: 3, "reps" => 10, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Mixed Keys Workout",
      exercises: exercises
    )
    
    assert result[:success]
    exercise = result[:workout_assignment][:exercises][0]
    assert_equal "bench press", exercise[:name]
    assert_equal 3, exercise[:sets]
    assert_equal 10, exercise[:reps]
    assert_equal 135.0, exercise[:weight]
  end
  
  test "should convert numeric values correctly" do
    exercises = [
      { name: "Test Exercise", sets: "5", reps: "12", weight: "150.5" }
    ]
    
    result = @tool.call(
      assignment_name: "Conversion Test",
      exercises: exercises
    )
    
    assert result[:success]
    exercise = result[:workout_assignment][:exercises][0]
    assert_equal 5, exercise[:sets]
    assert_equal 12, exercise[:reps]
    assert_equal 150.5, exercise[:weight]
  end
  
  test "should reject invalid exercises format" do
    result = @tool.call(
      assignment_name: "Invalid Workout",
      exercises: "not an array"
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid exercises format"
  end
  
  test "should reject exercises missing required fields" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10 } # missing weight
    ]
    
    result = @tool.call(
      assignment_name: "Missing Fields Workout",
      exercises: exercises
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid exercises format"
  end
  
  test "should reject exercises with empty name" do
    exercises = [
      { name: "", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Empty Name Workout",
      exercises: exercises
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid exercises format"
  end
  
  test "should reject exercises with zero sets" do
    exercises = [
      { name: "Bench Press", sets: 0, reps: 10, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Zero Sets Workout",
      exercises: exercises
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid exercises format"
  end
  
  test "should reject exercises with zero reps" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 0, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Zero Reps Workout",
      exercises: exercises
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid exercises format"
  end
  
  test "should accept exercises with zero weight" do
    exercises = [
      { name: "Bodyweight Exercise", sets: 3, reps: 10, weight: 0.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Bodyweight Workout",
      exercises: exercises
    )
    
    assert result[:success]
    exercise = result[:workout_assignment][:exercises][0]
    assert_equal 0.0, exercise[:weight]
  end
  
  test "should reject exercises with negative weight" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: -10.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Negative Weight Workout",
      exercises: exercises
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid exercises format"
  end
  
  test "should handle invalid timestamp format" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Invalid Time Workout",
      exercises: exercises,
      scheduled_for: "invalid-timestamp"
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid timestamp format"
  end
  
  test "should handle validation errors from workout assignment" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    # Test with empty assignment name to trigger validation error
    result = @tool.call(
      assignment_name: "",
      exercises: exercises
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Failed to create workout assignment"
  end
  
  test "should require authentication" do
    @tool.instance_variable_set(:@api_key, nil)
    
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(
        assignment_name: "Unauthenticated Workout",
        exercises: exercises
      )
    end
  end
  
  test "should require valid API key" do
    @tool.instance_variable_set(:@api_key, "invalid_key")
    
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(
        assignment_name: "Invalid Key Workout",
        exercises: exercises
      )
    end
  end
  
  test "should not work with revoked API key" do
    @api_key_record.revoke!
    
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(
        assignment_name: "Revoked Key Workout",
        exercises: exercises
      )
    end
  end
  
  test "should handle complex exercise configurations" do
    exercises = [
      { name: "Barbell Back Squat", sets: 5, reps: 5, weight: 225.0 },
      { name: "Romanian Deadlift", sets: 3, reps: 8, weight: 185.0 },
      { name: "Bulgarian Split Squat", sets: 3, reps: 12, weight: 45.0 },
      { name: "Walking Lunges", sets: 2, reps: 20, weight: 0.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Complex Lower Body Workout",
      exercises: exercises,
      scheduled_for: "2024-02-01T14:30:00Z"
    )
    
    assert result[:success]
    assert_equal 4, result[:workout_assignment][:exercises].length
    
    # Verify all exercises are properly processed
    exercise_names = result[:workout_assignment][:exercises].map { |ex| ex[:name] }
    assert_includes exercise_names, "barbell back squat"
    assert_includes exercise_names, "romanian deadlift"
    assert_includes exercise_names, "bulgarian split squat"
    assert_includes exercise_names, "walking lunges"
    
    # Verify bodyweight exercise (0 weight) is handled correctly
    lunges = result[:workout_assignment][:exercises].find { |ex| ex[:name] == "walking lunges" }
    assert_equal 0.0, lunges[:weight]
  end
  
  test "should handle edge case timestamps" do
    exercises = [
      { name: "Test Exercise", sets: 1, reps: 1, weight: 1.0 }
    ]
    
    # Test various timestamp formats
    valid_timestamps = [
      "2024-01-01T00:00:00Z",
      "2024-12-31T23:59:59Z",
      "2024-06-15T12:30:45+00:00"
    ]
    
    valid_timestamps.each do |timestamp|
      result = @tool.call(
        assignment_name: "Timestamp Test",
        exercises: exercises,
        scheduled_for: timestamp
      )
      
      assert result[:success], "Failed for timestamp: #{timestamp}"
      assert result[:workout_assignment][:scheduled_for]
    end
  end
  
  test "should return properly formatted response" do
    exercises = [
      { name: "Bench Press", sets: 3, reps: 10, weight: 135.0 }
    ]
    
    result = @tool.call(
      assignment_name: "Format Test Workout",
      exercises: exercises,
      scheduled_for: "2024-01-15T10:00:00Z"
    )
    
    assert result[:success]
    
    # Check response structure
    workout = result[:workout_assignment]
    assert workout[:id]
    assert_equal "Format Test Workout", workout[:assignment_name]
    assert workout[:exercises].is_a?(Array)
    assert_equal 1, workout[:exercises].length
    assert workout[:scheduled_for]
    
    # Check exercise structure
    exercise = workout[:exercises][0]
    assert_equal "bench press", exercise[:name]
    assert_equal 3, exercise[:sets]
    assert_equal 10, exercise[:reps]
    assert_equal 135.0, exercise[:weight]
    
    # Check message format
    assert_includes result[:message], "Successfully created workout assignment"
    assert_includes result[:message], "'Format Test Workout'"
    assert_includes result[:message], "2024-01-15 10:00"
  end
  
  test "should create assignment for current user only" do
    exercises = [
      { name: "Test Exercise", sets: 1, reps: 1, weight: 1.0 }
    ]
    
    result = @tool.call(
      assignment_name: "User Test Workout",
      exercises: exercises
    )
    
    assert result[:success]
    
    # Verify the assignment was created for the correct user
    assignment = WorkoutAssignment.find(result[:workout_assignment][:id])
    assert_equal @user.id, assignment.user_id
    
    # Verify it's accessible through user association
    assert_includes @user.workout_assignments, assignment
  end
end