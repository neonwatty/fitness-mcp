class ExerciseListResource < FastMcp::Resource
  uri "fitness://exercises"
  resource_name "Exercise List"
  description "List of all exercises with usage statistics"
  mime_type "application/json"
  
  def content
    # Get all unique exercises from the database
    exercises = SetEntry.group(:exercise)
                       .group_by(&:exercise)
                       .map do |exercise, sets|
      {
        name: exercise,
        total_sets: sets.count,
        total_users: sets.map(&:user_id).uniq.count,
        average_weight: sets.average(&:weight)&.round(2),
        max_weight: sets.maximum(&:weight),
        last_performed: sets.maximum(&:timestamp)&.iso8601,
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
end