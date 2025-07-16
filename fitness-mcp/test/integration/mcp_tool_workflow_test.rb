require "test_helper"

class McpToolWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
  end

  test "complete MCP tool workflow with data dependencies and audit logging" do
    # Clear any existing audit logs
    McpAuditLog.destroy_all
    
    # Step 1: Initialize tools with API key
    log_tool = LogSetTool.new(api_key: @api_key)
    get_last_set_tool = GetLastSetTool.new(api_key: @api_key)
    get_last_sets_tool = GetLastSetsTool.new(api_key: @api_key)
    get_recent_sets_tool = GetRecentSetsTool.new(api_key: @api_key)
    delete_last_set_tool = DeleteLastSetTool.new(api_key: @api_key)
    assign_workout_tool = AssignWorkoutTool.new(api_key: @api_key)
    
    # Step 2: Log multiple sets using LogSetTool
    workout_sets = [
      { exercise: "Bench Press", weight: 135, reps: 12 },
      { exercise: "Bench Press", weight: 155, reps: 10 },
      { exercise: "Bench Press", weight: 165, reps: 8 },
      { exercise: "Squat", weight: 185, reps: 10 },
      { exercise: "Squat", weight: 205, reps: 8 },
      { exercise: "Deadlift", weight: 225, reps: 5 }
    ]
    
    logged_set_ids = []
    workout_sets.each_with_index do |set_data, index|
      # Add slight time delays to simulate real workout
      travel_to (index * 3).minutes.ago do
        result = log_tool.call(**set_data)
        
        assert result[:success], "Failed to log set: #{result[:error]}"
        assert result[:set][:id], "Set ID not returned"
        assert_equal set_data[:exercise], result[:set][:exercise]
        assert_equal set_data[:weight], result[:set][:weight]
        assert_equal set_data[:reps], result[:set][:reps]
        
        logged_set_ids << result[:set][:id]
      end
    end
    
    # Verify all sets were logged
    assert_equal 6, @user.set_entries.count
    assert_equal 6, logged_set_ids.length
    assert_equal 6, McpAuditLog.where(tool_name: "LogSetTool", result_success: true).count
    
    # Step 3: Use GetLastSetTool to retrieve most recent set
    last_set_result = get_last_set_tool.call
    
    assert last_set_result[:success]
    assert last_set_result[:set]
    last_set = last_set_result[:set]
    
    # Should be the most recently logged set (Deadlift)
    assert_equal "Deadlift", last_set[:exercise]
    assert_equal 225, last_set[:weight]
    assert_equal 5, last_set[:reps]
    assert_equal logged_set_ids.last, last_set[:id]
    
    # Step 4: Use GetLastSetsTool to retrieve last 3 sets
    last_3_sets_result = get_last_sets_tool.call(count: 3)
    
    assert last_3_sets_result[:success]
    assert last_3_sets_result[:sets]
    last_3_sets = last_3_sets_result[:sets]
    
    assert_equal 3, last_3_sets.length
    # Should be in reverse chronological order
    assert_equal "Deadlift", last_3_sets[0][:exercise]
    assert_equal "Squat", last_3_sets[1][:exercise]
    assert_equal "Squat", last_3_sets[2][:exercise]
    
    # Step 5: Use GetLastSetsTool for specific exercise
    bench_sets_result = get_last_sets_tool.call(exercise: "Bench Press", count: 2)
    
    assert bench_sets_result[:success]
    bench_sets = bench_sets_result[:sets]
    
    assert_equal 2, bench_sets.length
    bench_sets.each do |set|
      assert_equal "Bench Press", set[:exercise]
    end
    # Should be heaviest sets first (most recent)
    assert bench_sets[0][:weight] > bench_sets[1][:weight]
    
    # Step 6: Use GetRecentSetsTool for date-based filtering
    recent_sets_result = get_recent_sets_tool.call(days: 1)
    
    assert recent_sets_result[:success]
    recent_sets = recent_sets_result[:sets]
    
    assert_equal 6, recent_sets.length # All sets should be within last day
    
    # Step 7: Create workout assignment using AssignWorkoutTool
    assignment_result = assign_workout_tool.call(
      assignment_name: "Push Day",
      scheduled_for: Date.tomorrow.iso8601,
      config: {
        exercises: [
          { name: "Bench Press", sets: 3, reps: 10, weight: 135 },
          { name: "Shoulder Press", sets: 3, reps: 8, weight: 95 }
        ],
        rest_time: 90
      }
    )
    
    assert assignment_result[:success], "Failed to assign workout: #{assignment_result[:error]}"
    assert assignment_result[:assignment]
    assignment = assignment_result[:assignment]
    
    assert_equal "Push Day", assignment[:assignment_name]
    assert assignment[:id]
    
    # Verify assignment was created in database
    assert_equal 1, @user.workout_assignments.count
    created_assignment = @user.workout_assignments.first
    assert_equal "Push Day", created_assignment.assignment_name
    
    # Step 8: Test DeleteLastSetTool
    initial_count = @user.set_entries.count
    last_set_before_delete = @user.set_entries.recent.first
    
    delete_result = delete_last_set_tool.call
    
    assert delete_result[:success]
    assert_equal "Last set deleted successfully", delete_result[:message]
    assert_equal initial_count - 1, @user.set_entries.count
    
    # Verify the correct set was deleted (most recent one)
    assert_not @user.set_entries.exists?(last_set_before_delete.id)
    
    # Step 9: Verify GetLastSetTool now returns different set
    new_last_set_result = get_last_set_tool.call
    
    assert new_last_set_result[:success]
    new_last_set = new_last_set_result[:set]
    
    # Should now be the second most recent set (Squat at 205 lbs)
    assert_equal "Squat", new_last_set[:exercise]
    assert_equal 205, new_last_set[:weight]
    assert_equal 8, new_last_set[:reps]
    
    # Step 10: Verify audit logging for all tool calls
    audit_logs = McpAuditLog.order(:created_at)
    
    # Should have logs for: 6 LogSetTool + 3 GetLastSetTool + 2 GetLastSetsTool + 1 GetRecentSetsTool + 1 AssignWorkoutTool + 1 DeleteLastSetTool = 14
    assert_equal 14, audit_logs.count
    
    # Verify log details
    log_tool_logs = audit_logs.where(tool_name: "LogSetTool")
    assert_equal 6, log_tool_logs.count
    log_tool_logs.each do |log|
      assert log.result_success
      assert log.execution_time > 0
      assert log.arguments.present?
    end
    
    # Verify GetLastSetTool logs
    get_last_set_logs = audit_logs.where(tool_name: "GetLastSetTool")
    assert_equal 3, get_last_set_logs.count # Called 3 times total
    
    # Verify DeleteLastSetTool log
    delete_logs = audit_logs.where(tool_name: "DeleteLastSetTool")
    assert_equal 1, delete_logs.count
    delete_log = delete_logs.first
    assert delete_log.result_success
    assert delete_log.execution_time > 0
  end
  
  test "MCP tool error handling and recovery workflow" do
    # Clear audit logs
    McpAuditLog.destroy_all
    
    # Step 1: Test tools with no data
    get_last_set_tool = GetLastSetTool.new(api_key: @api_key)
    delete_last_set_tool = DeleteLastSetTool.new(api_key: @api_key)
    
    # Try to get last set when no sets exist
    result = get_last_set_tool.call
    
    assert_not result[:success]
    assert_equal "No sets found for this exercise", result[:error]
    
    # Try to delete when no sets exist
    delete_result = delete_last_set_tool.call
    
    assert_not delete_result[:success]
    assert_equal "No sets found to delete", delete_result[:error]
    
    # Step 2: Test invalid authentication
    invalid_tool = LogSetTool.new(api_key: "invalid_key_12345")
    
    assert_raises(StandardError, "Authentication required. Please provide a valid API key.") do
      invalid_tool.call(exercise: "Test", weight: 100, reps: 10)
    end
    
    # Step 3: Test tool with invalid parameters
    log_tool = LogSetTool.new(api_key: @api_key)
    
    # Try to log set with invalid weight
    result = log_tool.call(exercise: "Test Exercise", weight: -50, reps: 10)
    
    assert_not result[:success]
    assert_includes result[:error], "Weight must be greater than or equal to 0"
    
    # Try to log set with invalid reps
    result = log_tool.call(exercise: "Test Exercise", weight: 100, reps: 0)
    
    assert_not result[:success]
    assert_includes result[:error], "Reps must be greater than 0"
    
    # Step 4: Verify error audit logs
    error_logs = McpAuditLog.where(result_success: false)
    assert error_logs.count > 0, "Should have audit logs for failed operations"
    
    error_logs.each do |log|
      assert_not log.result_success
      assert log.execution_time >= 0
    end
    
    # Step 5: Test recovery - log valid sets after errors
    valid_result = log_tool.call(exercise: "Recovery Test", weight: 100, reps: 10)
    
    assert valid_result[:success]
    assert_equal "Recovery Test", valid_result[:set][:exercise]
    
    # Verify database state is correct
    assert_equal 1, @user.set_entries.count
    assert_equal "Recovery Test", @user.set_entries.first.exercise
  end
  
  test "concurrent MCP tool operations" do
    # Test multiple tools operating on the same user data
    log_tool = LogSetTool.new(api_key: @api_key)
    get_recent_tool = GetRecentSetsTool.new(api_key: @api_key)
    
    # Log sets and retrieve data concurrently
    threads = []
    
    # Thread 1: Log multiple sets
    threads << Thread.new do
      5.times do |i|
        log_tool.call(
          exercise: "Concurrent Exercise #{i}",
          weight: 100 + (i * 10),
          reps: 10 - i
        )
        sleep(0.1) # Small delay to simulate real timing
      end
    end
    
    # Thread 2: Repeatedly check recent sets
    results = []
    threads << Thread.new do
      5.times do
        result = get_recent_tool.call(days: 1)
        results << result[:sets]&.length || 0
        sleep(0.1)
      end
    end
    
    # Wait for both threads to complete
    threads.each(&:join)
    
    # Verify final state
    assert_equal 5, @user.set_entries.count
    
    # Verify that GetRecentSetsTool saw increasing numbers of sets
    assert results.any? { |count| count > 0 }, "GetRecentSetsTool should have seen some sets"
    assert results.last >= results.first, "Set count should have increased over time"
  end
  
  test "tool workflow with mixed authentication scenarios" do
    # Create second user and API key
    user2 = create_user(email: "user2@example.com")
    api_key_record2, api_key2 = create_api_key(user: user2)
    
    # Tools for both users
    user1_log_tool = LogSetTool.new(api_key: @api_key)
    user2_log_tool = LogSetTool.new(api_key: api_key2)
    user1_get_tool = GetLastSetTool.new(api_key: @api_key)
    user2_get_tool = GetLastSetTool.new(api_key: api_key2)
    
    # Log sets for both users
    user1_log_tool.call(exercise: "User 1 Exercise", weight: 100, reps: 10)
    user2_log_tool.call(exercise: "User 2 Exercise", weight: 150, reps: 8)
    
    # Verify data isolation
    user1_result = user1_get_tool.call
    user2_result = user2_get_tool.call
    
    assert user1_result[:success]
    assert user2_result[:success]
    
    assert_equal "User 1 Exercise", user1_result[:set][:exercise]
    assert_equal "User 2 Exercise", user2_result[:set][:exercise]
    
    # Verify database isolation
    assert_equal 1, @user.set_entries.count
    assert_equal 1, user2.set_entries.count
    assert_equal "User 1 Exercise", @user.set_entries.first.exercise
    assert_equal "User 2 Exercise", user2.set_entries.first.exercise
  end
end