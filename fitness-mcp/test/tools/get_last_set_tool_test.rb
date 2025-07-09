require "test_helper"

class GetLastSetToolTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @tool = GetLastSetTool.new
    
    # Mock the API key for the tool
    @tool.instance_variable_set(:@api_key, @api_key)
  end

  test "should get last set for specific exercise" do
    # Create some sets
    @user.set_entries.create!(
      exercise: "bench press",
      weight: 135.0,
      reps: 10,
      timestamp: 2.hours.ago
    )
    last_set = @user.set_entries.create!(
      exercise: "bench press",
      weight: 140.0,
      reps: 8,
      timestamp: 1.hour.ago
    )
    @user.set_entries.create!(
      exercise: "squat",
      weight: 185.0,
      reps: 8,
      timestamp: 30.minutes.ago
    )
    
    result = @tool.call(exercise: "Bench Press")
    
    assert result[:success]
    assert_includes result[:message], "Last Bench Press: 8 reps at 140.0 lbs"
    assert_present result[:set_entry]
    assert_equal last_set.id, result[:set_entry][:id]
    assert_equal "bench press", result[:set_entry][:exercise]
    assert_equal 140.0, result[:set_entry][:weight]
    assert_equal 8, result[:set_entry][:reps]
  end

  test "should return message when no sets exist for exercise" do
    result = @tool.call(exercise: "Deadlift")
    
    assert_not result[:success]
    assert_equal "No sets found for Deadlift", result[:message]
    assert_nil result[:set_entry]
  end

  test "should normalize exercise names" do
    @user.set_entries.create!(
      exercise: "bench press",
      weight: 135.0,
      reps: 10,
      timestamp: 1.hour.ago
    )
    
    result = @tool.call(exercise: "  BENCH PRESS  ")
    
    assert result[:success]
    assert_present result[:set_entry]
  end

  test "should require authentication" do
    @tool.instance_variable_set(:@api_key, nil)
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "Bench Press")
    end
  end

  test "should require valid API key" do
    @tool.instance_variable_set(:@api_key, "invalid_key")
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "Bench Press")
    end
  end

  test "should not work with revoked API key" do
    @api_key_record.revoke!
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      @tool.call(exercise: "Bench Press")
    end
  end
end