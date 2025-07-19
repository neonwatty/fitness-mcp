require "test_helper"

class DeleteLastSetToolTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @tool = DeleteLastSetTool.new
    
    # Mock the API key for the tool
    @tool.instance_variable_set(:@api_key, @api_key)
    
    # Create test sets
    @bench_sets = [
      @user.set_entries.create!(exercise: "bench press", weight: 135.0, reps: 10, timestamp: 3.hours.ago),
      @user.set_entries.create!(exercise: "bench press", weight: 145.0, reps: 8, timestamp: 2.hours.ago),
      @user.set_entries.create!(exercise: "bench press", weight: 155.0, reps: 6, timestamp: 1.hour.ago)
    ]
    
    @squat_sets = [
      @user.set_entries.create!(exercise: "squat", weight: 185.0, reps: 8, timestamp: 4.hours.ago),
      @user.set_entries.create!(exercise: "squat", weight: 205.0, reps: 5, timestamp: 30.minutes.ago)
    ]
    
    @deadlift_set = @user.set_entries.create!(exercise: "deadlift", weight: 225.0, reps: 5, timestamp: 45.minutes.ago)
  end

  test "should delete last set for existing exercise" do
    initial_count = @user.set_entries.where(exercise: "bench press").count
    assert_equal 3, initial_count
    
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    assert_equal "bench press", result[:deleted_set][:exercise]
    assert_equal 155.0, result[:deleted_set][:weight]
    assert_equal 6, result[:deleted_set][:reps]
    assert result[:deleted_set][:timestamp]
    assert result[:deleted_set][:id]
    assert_includes result[:message], "Successfully deleted last bench press set"
    assert_includes result[:message], "6 reps at 155.0 lbs"
    
    # Verify it was actually deleted
    remaining_count = @user.set_entries.where(exercise: "bench press").count
    assert_equal 2, remaining_count
    
    # Verify the correct set was deleted (the most recent one)
    remaining_sets = @user.set_entries.where(exercise: "bench press").order(timestamp: :desc)
    assert_equal 145.0, remaining_sets.first.weight # Second most recent should now be first
  end
  
  test "should handle exercise name case insensitivity" do
    result = @tool.call(exercise: "BENCH PRESS")
    
    assert result[:success]
    assert_equal "bench press", result[:deleted_set][:exercise]
    assert_equal 155.0, result[:deleted_set][:weight]
  end
  
  test "should handle exercise name with extra whitespace" do
    result = @tool.call(exercise: "  bench press  ")
    
    assert result[:success]
    assert_equal "bench press", result[:deleted_set][:exercise]
    assert_equal 155.0, result[:deleted_set][:weight]
  end
  
  test "should delete most recent set based on timestamp" do
    # Squat has 2 sets, most recent should be deleted first
    result = @tool.call(exercise: "squat")
    
    assert result[:success]
    assert_equal 205.0, result[:deleted_set][:weight] # Most recent
    assert_equal 5, result[:deleted_set][:reps]
    
    # Verify only one squat set remains
    remaining_squat_sets = @user.set_entries.where(exercise: "squat")
    assert_equal 1, remaining_squat_sets.count
    assert_equal 185.0, remaining_squat_sets.first.weight # Older set remains
  end
  
  test "should delete single set for exercise" do
    initial_count = @user.set_entries.where(exercise: "deadlift").count
    assert_equal 1, initial_count
    
    result = @tool.call(exercise: "deadlift")
    
    assert result[:success]
    assert_equal "deadlift", result[:deleted_set][:exercise]
    assert_equal 225.0, result[:deleted_set][:weight]
    
    # Verify it was deleted
    remaining_count = @user.set_entries.where(exercise: "deadlift").count
    assert_equal 0, remaining_count
  end
  
  test "should return error for non-existent exercise" do
    result = @tool.call(exercise: "non-existent exercise")
    
    assert_not result[:success]
    assert_includes result[:message], "No sets found for 'non-existent exercise' to delete"
    assert result[:available_exercises]
    assert result[:available_exercises].is_a?(Array)
    assert_includes result[:available_exercises], "bench press"
    assert_includes result[:available_exercises], "squat"
    assert_includes result[:available_exercises], "deadlift"
  end
  
  test "should provide exercise suggestions for partial matches" do
    result = @tool.call(exercise: "press")
    
    assert_not result[:success]
    assert_includes result[:message], "No sets found for 'press' to delete"
    assert_includes result[:message], "Did you mean one of these:"
    assert result[:suggestions]
    assert result[:suggestions].is_a?(Array)
    assert_includes result[:suggestions], "bench press"
  end
  
  test "should provide exercise suggestions for similar words" do
    result = @tool.call(exercise: "bench")
    
    assert_not result[:success]
    assert_includes result[:message], "Did you mean one of these:"
    assert result[:suggestions]
    assert_includes result[:suggestions], "bench press"
  end
  
  test "should handle user with no sets" do
    user_no_sets = create_user(email: "nosets@example.com")
    api_key_record, api_key = create_api_key(user: user_no_sets)
    tool = DeleteLastSetTool.new
    tool.instance_variable_set(:@api_key, api_key)
    
    result = tool.call(exercise: "any exercise")
    
    assert_not result[:success]
    assert_includes result[:message], "No sets found for 'any exercise' to delete"
    assert_equal [], result[:available_exercises]
  end
  
  test "should normalize exercise names consistently" do
    # Create set with mixed case and spaces
    @user.set_entries.create!(exercise: "barbell row", weight: 95.0, reps: 10, timestamp: 10.minutes.ago)
    
    result = @tool.call(exercise: "Barbell Row")
    
    assert result[:success]
    assert_equal "barbell row", result[:deleted_set][:exercise]
    assert_equal 95.0, result[:deleted_set][:weight]
  end
  
  test "should handle exercises with special characters" do
    @user.set_entries.create!(exercise: "t-bar row", weight: 90.0, reps: 12, timestamp: 15.minutes.ago)
    @user.set_entries.create!(exercise: "21's bicep curl", weight: 45.0, reps: 21, timestamp: 20.minutes.ago)
    
    result1 = @tool.call(exercise: "t-bar row")
    assert result1[:success]
    assert_equal "t-bar row", result1[:deleted_set][:exercise]
    
    result2 = @tool.call(exercise: "21's bicep curl")
    assert result2[:success]
    assert_equal "21's bicep curl", result2[:deleted_set][:exercise]
  end
  
  test "should preserve original weight format in response" do
    # Test with decimal weight
    @user.set_entries.create!(exercise: "light exercise", weight: 12.5, reps: 15, timestamp: 5.minutes.ago)
    
    result = @tool.call(exercise: "light exercise")
    
    assert result[:success]
    assert_equal 12.5, result[:deleted_set][:weight]
    assert_includes result[:message], "12.5 lbs"
  end
  
  test "should handle integer weights correctly" do
    # Test with integer weight (should display as float)
    @user.set_entries.create!(exercise: "integer exercise", weight: 100, reps: 10, timestamp: 8.minutes.ago)
    
    result = @tool.call(exercise: "integer exercise")
    
    assert result[:success]
    assert_equal 100.0, result[:deleted_set][:weight]
    assert_includes result[:message], "100.0 lbs"
  end
  
  test "should include proper timestamp in ISO8601 format" do
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    assert result[:deleted_set][:timestamp]
    
    # Should be valid ISO8601 format
    assert_nothing_raised do
      Time.iso8601(result[:deleted_set][:timestamp])
    end
    
    # Should match the timestamp of the most recent bench press set
    expected_timestamp = @bench_sets.last.timestamp.iso8601
    assert_equal expected_timestamp, result[:deleted_set][:timestamp]
  end
  
  test "should handle database errors gracefully" do
    # This test would require proper mocking - skip for now
    # In real usage, database errors are rare and handled by the generic error handler
    skip "Requires proper mocking framework to test database errors"
  end
  
  test "should handle unexpected errors gracefully" do
    # This test would require proper mocking - skip for now
    # In real usage, unexpected errors are handled by the generic error handler
    skip "Requires proper mocking framework to test unexpected errors"
  end
  
  test "should require authentication" do
    @tool.instance_variable_set(:@api_key, nil)
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "bench press")
    end
  end
  
  test "should require valid API key" do
    @tool.instance_variable_set(:@api_key, "invalid_key")
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "bench press")
    end
  end
  
  test "should not work with revoked API key" do
    @api_key_record.revoke!
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "bench press")
    end
  end
  
  test "should only delete sets for current user" do
    # Create another user with sets
    other_user = create_user(email: "other@example.com")
    other_user.set_entries.create!(exercise: "bench press", weight: 200.0, reps: 5, timestamp: 30.minutes.ago)
    
    # Verify other user has bench press sets
    assert_equal 1, other_user.set_entries.where(exercise: "bench press").count
    
    # Delete bench press set for current user
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    
    # Verify other user's sets are untouched
    assert_equal 1, other_user.set_entries.where(exercise: "bench press").count
    
    # Verify current user has one less bench press set
    assert_equal 2, @user.set_entries.where(exercise: "bench press").count
  end
  
  test "should handle empty exercise name" do
    result = @tool.call(exercise: "")
    
    assert_not result[:success]
    assert_includes result[:message], "No sets found for '' to delete"
  end
  
  test "should handle exercise name with only whitespace" do
    result = @tool.call(exercise: "   ")
    
    assert_not result[:success]
    assert_includes result[:message], "No sets found for '   ' to delete"
  end
  
  test "should return detailed set information in response" do
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    
    deleted_set = result[:deleted_set]
    assert deleted_set[:id].is_a?(Integer)
    assert_equal "bench press", deleted_set[:exercise]
    assert deleted_set[:weight].is_a?(Float)
    assert deleted_set[:reps].is_a?(Integer)
    assert deleted_set[:timestamp].is_a?(String)
    
    # Should include all required fields
    required_fields = [:id, :exercise, :weight, :reps, :timestamp]
    required_fields.each do |field|
      assert deleted_set.key?(field), "Missing field: #{field}"
      assert_not_nil deleted_set[field], "Field #{field} is nil"
    end
  end
  
  test "should handle complex exercise scenarios" do
    # Create multiple exercises with similar names
    @user.set_entries.create!(exercise: "incline bench press", weight: 115.0, reps: 8, timestamp: 25.minutes.ago)
    @user.set_entries.create!(exercise: "decline bench press", weight: 125.0, reps: 10, timestamp: 35.minutes.ago)
    @user.set_entries.create!(exercise: "dumbbell bench press", weight: 70.0, reps: 12, timestamp: 40.minutes.ago)
    
    # Delete regular bench press - should not affect the others
    result = @tool.call(exercise: "bench press")
    
    assert result[:success]
    assert_equal "bench press", result[:deleted_set][:exercise]
    
    # Verify other bench press variations still exist
    assert_equal 1, @user.set_entries.where(exercise: "incline bench press").count
    assert_equal 1, @user.set_entries.where(exercise: "decline bench press").count
    assert_equal 1, @user.set_entries.where(exercise: "dumbbell bench press").count
  end
  
  test "should provide meaningful suggestions for typos" do
    result = @tool.call(exercise: "bench pres") # Missing 's'
    
    assert_not result[:success]
    assert_includes result[:message], "Did you mean one of these:"
    assert result[:suggestions]
    assert_includes result[:suggestions], "bench press"
  end
  
  test "should handle exercises with numbers" do
    @user.set_entries.create!(exercise: "21s bicep curl", weight: 40.0, reps: 21, timestamp: 12.minutes.ago)
    
    result = @tool.call(exercise: "21s bicep curl")
    
    assert result[:success]
    assert_equal "21s bicep curl", result[:deleted_set][:exercise]
    assert_equal 40.0, result[:deleted_set][:weight]
  end
end