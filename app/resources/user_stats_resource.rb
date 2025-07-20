class UserStatsResource < FastMcp::Resource
  uri "fitness://stats/{user_id}"
  resource_name "User Statistics"
  description "Comprehensive fitness statistics and analytics for a user"
  mime_type "application/json"
  
  def content
    # For templated resources, we need to get the user_id from params
    user_id = params[:user_id]
    
    # Authenticate user access
    unless can_access_user_data?(user_id)
      raise StandardError, "Access denied to user #{user_id} statistics"
    end
    
    user = User.find(user_id)
    
    # Calculate time period for stats (default 30 days)
    days_back = 30
    since_date = days_back.days.ago
    
    # Get base queries
    all_sets = user.set_entries
    recent_sets = all_sets.where('timestamp >= ?', since_date)
    
    # Calculate comprehensive stats
    stats_data = {
      user_id: user.id,
      user_email: user.email,
      period_days: days_back,
      
      # Overall statistics
      total_sets: all_sets.count,
      recent_sets: recent_sets.count,
      total_weight_moved: all_sets.sum('weight * reps'),
      recent_weight_moved: recent_sets.sum('weight * reps'),
      
      # Exercise diversity
      unique_exercises: all_sets.distinct.count(:exercise),
      recent_exercises: recent_sets.distinct.count(:exercise),
      
      # Exercise breakdown
      exercise_stats: calculate_exercise_stats(recent_sets),
      
      # Progress tracking
      strength_progress: calculate_strength_progress(user, recent_sets),
      
      # Workout assignments
      active_assignments: user.workout_assignments.active.count,
      
      # Recent activity
      last_workout: all_sets.order(:timestamp).last&.timestamp&.iso8601,
      days_since_last_workout: all_sets.any? ? 
        (Time.current - all_sets.order(:timestamp).last.timestamp).to_i / 1.day : nil
    }
    
    JSON.pretty_generate(stats_data)
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
  
  def calculate_exercise_stats(sets)
    sets.group_by(&:exercise).map do |exercise, exercise_sets|
      {
        exercise: exercise,
        total_sets: exercise_sets.count,
        total_reps: exercise_sets.sum(&:reps),
        total_weight: exercise_sets.sum { |s| s.weight.to_f * s.reps },
        max_weight: exercise_sets.map(&:weight).map(&:to_f).max,
        average_weight: (exercise_sets.map(&:weight).map(&:to_f).sum / exercise_sets.count).round(2),
        last_performed: exercise_sets.map(&:timestamp).max&.iso8601
      }
    end
  end
  
  def calculate_strength_progress(user, recent_sets)
    # Calculate strength progress for main exercises
    main_exercises = %w[squat deadlift bench press]
    
    main_exercises.map do |exercise|
      exercise_sets = recent_sets.where('exercise LIKE ?', "%#{exercise}%")
      next unless exercise_sets.any?
      
      # Get first and last recorded weights
      first_set = exercise_sets.order(:timestamp).first
      last_set = exercise_sets.order(:timestamp).last
      
      first_weight = first_set.weight.to_f
      last_weight = last_set.weight.to_f
      improvement = last_weight - first_weight
      improvement_percentage = first_weight > 0 ? ((improvement / first_weight) * 100).round(2) : 0
      
      {
        exercise: exercise,
        first_weight: first_weight,
        last_weight: last_weight,
        improvement: improvement,
        improvement_percentage: improvement_percentage,
        sets_performed: exercise_sets.count
      }
    end.compact
  end
end