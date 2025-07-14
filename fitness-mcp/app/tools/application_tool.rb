class ApplicationTool < FastMcp::Tool
  def initialize(api_key: nil)
    @api_key = api_key || ENV['API_KEY']
    super()
  end
  
  def call(**args)
    # Authentication and audit logging
    authenticate_user!
    
    start_time = Time.current
    result = nil
    success = false
    
    begin
      result = perform(**args)
      success = result.is_a?(Hash) ? result.fetch(:success, true) : true
      result
    rescue => e
      success = false
      result = { success: false, error: e.message }
      raise
    ensure
      # Log the tool usage
      log_audit(result_success: success, execution_time: Time.current - start_time)
    end
  end
  
  def authenticate_user!
    api_key = @api_key
    
    unless api_key && current_user(api_key)
      raise StandardError, "Authentication required. Please provide a valid API key."
    end
  end
  
  protected
  
  def current_user(api_key = nil)
    api_key ||= @api_key
    return nil unless api_key.present?
    
    key_hash = ApiKey.hash_key(api_key)
    api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    api_key_record&.user
  end
  
  def current_api_key_record(api_key = nil)
    api_key ||= @api_key
    return nil unless api_key.present?
    
    key_hash = ApiKey.hash_key(api_key)
    ApiKey.active.find_by(api_key_hash: key_hash)
  end
  
  def api_key
    @api_key
  end
  
  private
  
  def log_audit(result_success:, execution_time:)
    user = current_user
    api_key_record = current_api_key_record
    
    return unless user && api_key_record
    
    begin
      McpAuditLog.log_tool_usage(
        user: user,
        api_key: api_key_record,
        tool_name: self.class.name,
        arguments: {},
        result_success: result_success,
        ip_address: extract_ip_address
      )
    rescue => e
      # Don't let audit logging failure break the main functionality
      if defined?(Rails)
        Rails.logger.error "Failed to log MCP tool usage: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
  
  def extract_ip_address
    # Use default for now
    'MCP_CLIENT'
  end
end