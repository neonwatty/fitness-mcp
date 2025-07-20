require 'test_helper'

class GetRecentSetsToolTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
    @tool = GetRecentSetsTool.new(api_key: @api_key)
  end

  test "should get recent sets across all exercises" do
    # Create test data
    @user.set_entries.create!(exercise: "bench press", weight: 185.0, reps: 8, timestamp: 1.hour.ago)
    @user.set_entries.create!(exercise: "squat", weight: 225.0, reps: 5, timestamp: 30.minutes.ago)
    @user.set_entries.create!(exercise: "deadlift", weight: 315.0, reps: 3, timestamp: 10.minutes.ago)
    
    result = @tool.call(limit: 2)
    
    assert result[:success]
    assert_equal 2, result[:count]
    assert_equal 2, result[:set_entries].length
    
    # Should be ordered by most recent first
    assert_equal "deadlift", result[:set_entries][0][:exercise]
    assert_equal "squat", result[:set_entries][1][:exercise]
  end
  
  test "should use default limit when not specified" do
    # Create 15 sets to test default limit
    15.times do |i|
      @user.set_entries.create!(
        exercise: "exercise_#{i}", 
        weight: 100.0, 
        reps: 10, 
        timestamp: (15 - i).minutes.ago
      )
    end
    
    result = @tool.call
    
    assert result[:success]
    assert_equal 10, result[:count]  # Default limit should be 10
  end
  
  test "should enforce maximum limit" do
    # Create many sets
    60.times do |i|
      @user.set_entries.create!(
        exercise: "exercise_#{i}", 
        weight: 100.0, 
        reps: 10, 
        timestamp: (60 - i).minutes.ago
      )
    end
    
    result = @tool.call(limit: 100)  # Request more than max
    
    assert result[:success]
    assert_equal 50, result[:count]  # Should be capped at 50
  end
  
  test "should handle no sets found" do
    result = @tool.call
    
    assert_not result[:success]
    assert_equal "No sets found", result[:message]
  end
  
  test "should require authentication" do
    unauthenticated_tool = GetRecentSetsTool.new(api_key: nil)
    
    assert_raises StandardError, "Authentication required. Please provide a valid API key." do
      unauthenticated_tool.call
    end
  end
  
  test "should log tool usage to audit log" do
    # Create some test data
    @user.set_entries.create!(exercise: "bench press", weight: 185.0, reps: 8, timestamp: 1.hour.ago)
    
    assert_difference 'McpAuditLog.count', 1 do
      @tool.call(limit: 5)
    end
    
    log = McpAuditLog.last
    assert_equal @user.id, log.user_id
    assert_equal @api_key_record.id, log.api_key_id
    assert_equal 'GetRecentSetsTool', log.tool_name
    assert_equal({'limit' => 5}, log.parsed_arguments)
    assert_equal true, log.result_success
    assert_equal 'MCP_CLIENT', log.ip_address
    assert_not_nil log.timestamp
  end
  
  test "should log failed tool usage to audit log" do
    # Create tool with invalid API key
    invalid_tool = GetRecentSetsTool.new(api_key: "invalid_key")
    
    assert_difference 'McpAuditLog.count', 0 do
      assert_raises StandardError do
        invalid_tool.call(limit: 5)
      end
    end
    
    # Failed authentication should not create audit log since user cannot be determined
  end
end