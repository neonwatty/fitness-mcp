require "test_helper"

class LogSetToolTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @tool = LogSetTool.new
    
    # Mock the API key for the tool
    @tool.instance_variable_set(:@api_key, @api_key)
  end

  test "should log set with valid data" do
    result = @tool.call(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10
    )
    
    assert result[:success]
    assert_equal "Successfully logged 10 reps of Bench Press at 135.0 lbs", result[:message]
    assert_not_nil result[:set_entry]
    assert_equal "bench press", result[:set_entry][:exercise]
    assert_equal 135.0, result[:set_entry][:weight]
    assert_equal 10, result[:set_entry][:reps]
    
    # Verify the set was actually created
    assert_equal 1, @user.set_entries.count
    set_entry = @user.set_entries.first
    assert_equal "bench press", set_entry.exercise
    assert_equal 135.0, set_entry.weight
    assert_equal 10, set_entry.reps
  end

  test "should log set with custom timestamp" do
    timestamp = "2023-01-01T12:00:00Z"
    result = @tool.call(
      exercise: "Squat",
      weight: 185.0,
      reps: 8,
      timestamp: timestamp
    )
    
    assert result[:success]
    assert_equal Time.parse(timestamp).iso8601, result[:set_entry][:timestamp]
    
    set_entry = @user.set_entries.first
    assert_equal Time.parse(timestamp), set_entry.timestamp
  end

  test "should normalize exercise names" do
    @tool.call(
      exercise: "  BENCH PRESS  ",
      weight: 135.0,
      reps: 10
    )
    
    set_entry = @user.set_entries.first
    assert_equal "bench press", set_entry.exercise
  end

  test "should handle invalid timestamp format" do
    result = @tool.call(
      exercise: "Bench Press",
      weight: 135.0,
      reps: 10,
      timestamp: "invalid-timestamp"
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid timestamp format"
  end

  test "should handle validation errors" do
    result = @tool.call(
      exercise: "Bench Press",
      weight: -10.0,
      reps: 0
    )
    
    assert_not result[:success]
    assert_includes result[:error], "Failed to log set"
    assert_includes result[:error], "Weight must be greater than 0"
    assert_includes result[:error], "Reps must be greater than 0"
  end

  test "should require authentication" do
    @tool.instance_variable_set(:@api_key, nil)
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(
        exercise: "Bench Press",
        weight: 135.0,
        reps: 10
      )
    end
  end

  test "should require valid API key" do
    @tool.instance_variable_set(:@api_key, "invalid_key")
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(
        exercise: "Bench Press",
        weight: 135.0,
        reps: 10
      )
    end
  end

  test "should not work with revoked API key" do
    @api_key_record.revoke!
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(
        exercise: "Bench Press",
        weight: 135.0,
        reps: 10
      )
    end
  end
end