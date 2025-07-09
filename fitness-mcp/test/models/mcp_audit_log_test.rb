require 'test_helper'

class McpAuditLogTest < ActiveSupport::TestCase
  def setup
    @user = create_user
    @api_key_record, @api_key = create_api_key(user: @user)
  end

  test "should create audit log entry" do
    assert_difference 'McpAuditLog.count', 1 do
      McpAuditLog.log_tool_usage(
        user: @user,
        api_key: @api_key_record,
        tool_name: 'TestTool',
        arguments: { test: 'value' },
        result_success: true,
        ip_address: '127.0.0.1'
      )
    end
    
    log = McpAuditLog.last
    assert_equal @user, log.user
    assert_equal @api_key_record, log.api_key
    assert_equal 'TestTool', log.tool_name
    assert_equal({ 'test' => 'value' }, log.parsed_arguments)
    assert_equal true, log.result_success
    assert_equal '127.0.0.1', log.ip_address
    assert_not_nil log.timestamp
  end

  test "should validate required fields" do
    log = McpAuditLog.new
    assert_not log.valid?
    
    assert_includes log.errors[:user], "must exist"
    assert_includes log.errors[:api_key], "must exist"
    assert_includes log.errors[:tool_name], "can't be blank"
    assert_includes log.errors[:arguments], "can't be blank"
    assert_includes log.errors[:result_success], "is not included in the list"
    assert_includes log.errors[:timestamp], "can't be blank"
  end

  test "should scope by recent" do
    old_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'OldTool',
      arguments: {},
      result_success: true
    )
    
    # Update the timestamp to be older
    old_log.update!(timestamp: 1.hour.ago)
    
    new_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'NewTool',
      arguments: {},
      result_success: true
    )
    
    user_logs = McpAuditLog.where(user: @user).recent
    assert_equal new_log.id, user_logs.first.id
    assert_equal old_log.id, user_logs.last.id
  end

  test "should scope by success/failure" do
    success_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'SuccessTool',
      arguments: {},
      result_success: true
    )
    
    failure_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'FailureTool',
      arguments: {},
      result_success: false
    )
    
    assert_includes McpAuditLog.successful, success_log
    assert_not_includes McpAuditLog.successful, failure_log
    
    assert_includes McpAuditLog.failed, failure_log
    assert_not_includes McpAuditLog.failed, success_log
  end

  test "should scope by tool name" do
    tool_a_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'ToolA',
      arguments: {},
      result_success: true
    )
    
    tool_b_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'ToolB',
      arguments: {},
      result_success: true
    )
    
    tool_a_logs = McpAuditLog.for_tool('ToolA')
    assert_includes tool_a_logs, tool_a_log
    assert_not_includes tool_a_logs, tool_b_log
  end

  test "should scope by time" do
    old_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'OldTool',
      arguments: {},
      result_success: true
    )
    
    # Update the timestamp to be older
    old_log.update!(timestamp: 2.hours.ago)
    
    new_log = McpAuditLog.log_tool_usage(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'NewTool',
      arguments: {},
      result_success: true
    )
    
    recent_logs = McpAuditLog.since(1.hour.ago)
    assert_includes recent_logs, new_log
    assert_not_includes recent_logs, old_log
  end

  test "should handle invalid JSON gracefully" do
    log = McpAuditLog.create!(
      user: @user,
      api_key: @api_key_record,
      tool_name: 'TestTool',
      arguments: 'invalid json',
      result_success: true,
      timestamp: Time.current
    )
    
    assert_equal({}, log.parsed_arguments)
  end
end
