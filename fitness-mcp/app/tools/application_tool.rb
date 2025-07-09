class ApplicationTool < MCP::Tool
  def call(**args)
    # Override to add authentication
    authenticate_user!
    super
  end
  
  protected
  
  def current_user
    return nil unless api_key.present?
    
    key_hash = ApiKey.hash_key(api_key)
    api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    api_key_record&.user
  end
  
  def api_key
    # For now, we'll need to implement proper API key extraction
    # This is a placeholder until we understand the gem better
    @api_key ||= ENV['API_KEY']
  end
  
  def authenticate_user!
    unless current_user
      raise StandardError, "Authentication required. Please provide a valid API key."
    end
  end
end