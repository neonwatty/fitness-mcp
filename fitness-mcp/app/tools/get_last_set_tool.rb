class GetLastSetTool < ApplicationTool
  description "Get the most recent set for a specific exercise"
  
  arguments do
    required(:exercise).filled(:string).description("Name of the exercise to query")
  end
  
  def call(exercise:)
    authenticate_user!
    
    normalized_exercise = exercise.strip.downcase
    last_set = current_user.set_entries
                          .for_exercise(normalized_exercise)
                          .recent
                          .first
    
    if last_set
      {
        success: true,
        set_entry: {
          id: last_set.id,
          exercise: last_set.exercise,
          weight: last_set.weight,
          reps: last_set.reps,
          timestamp: last_set.timestamp.iso8601
        },
        message: "Last #{exercise}: #{last_set.reps} reps at #{last_set.weight} lbs on #{last_set.timestamp.strftime('%Y-%m-%d %H:%M')}"
      }
    else
      {
        success: false,
        message: "No sets found for #{exercise}"
      }
    end
  end
end