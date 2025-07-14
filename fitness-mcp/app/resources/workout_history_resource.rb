class WorkoutHistoryResource < FastMcp::Resource
  uri "fitness://history/{user_id}"
  resource_name "Workout History"
  description "Complete workout history for a user including all logged sets"
  mime_type "application/json"
  
  def content
    # For templated resources, we need to get the user_id from params
    user_id = params[:user_id]
    
    # Authenticate user access
    unless can_access_user_data?(user_id)
      raise StandardError, "Access denied to user #{user_id} workout history"
    end
    
    user = User.find(user_id)
    
    # Get recent workout history (limit to 50 for performance)
    sets = user.set_entries
               .includes(:user)
               .order(timestamp: :desc)
               .limit(50)
    
    history_data = {
      user_id: user.id,
      user_email: user.email,
      total_sets: user.set_entries.count,
      recent_sets: sets.map do |set|
        {
          id: set.id,
          exercise: set.exercise,
          weight: set.weight,
          reps: set.reps,
          timestamp: set.timestamp.iso8601,
          created_at: set.created_at.iso8601
        }
      end
    }
    
    JSON.pretty_generate(history_data)
  end
  
  private
  
  def can_access_user_data?(user_id)
    # Check if current user can access this user's data
    current_user_id = current_user&.id
    return false unless current_user_id
    
    # Users can access their own data, admins can access any user's data
    current_user_id.to_s == user_id.to_s || current_user&.admin?
  end
  
  def current_user
    api_key = ENV['API_KEY']
    return nil unless api_key
    
    key_hash = ApiKey.hash_key(api_key)
    api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    api_key_record&.user
  end
end