class ExerciseListResource < FastMcp::Resource
  uri "fitness://exercises"
  resource_name "Exercise List"
  description "List of all exercises with usage statistics"
  mime_type "application/json"
  
  def content
    # Authenticate user
    unless current_user
      raise StandardError, "Authentication required to access exercise list"
    end
    
    # Get all unique exercises from the database
    exercises = SetEntry.all.group_by(&:exercise).map do |exercise, sets|
      weights = sets.map { |s| s.weight.to_f }
      {
        name: exercise,
        total_sets: sets.count,
        total_users: sets.map(&:user_id).uniq.count,
        average_weight: (weights.sum / sets.count).round(2),
        max_weight: weights.max,
        last_performed: sets.map(&:timestamp).max&.iso8601,
        popularity_rank: nil # Will be calculated below
      }
    end
    
    # Sort by popularity (total sets) and assign ranks
    exercises.sort_by! { |e| -e[:total_sets] }
    exercises.each_with_index { |exercise, index| exercise[:popularity_rank] = index + 1 }
    
    exercise_data = {
      total_exercises: exercises.count,
      exercises: exercises
    }
    
    JSON.pretty_generate(exercise_data)
  end
  
  private
  
  def current_user
    api_key = ENV['API_KEY']
    return nil unless api_key
    
    key_hash = ApiKey.hash_key(api_key)
    api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    api_key_record&.user
  end
end