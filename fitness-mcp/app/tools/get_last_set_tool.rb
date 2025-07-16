class GetLastSetTool < ApplicationTool
  description "Get the most recent set for a specific exercise"
  
  arguments do
    required(:exercise).filled(:string).description("Name of the exercise to query")
  end
  
  def perform(exercise:)
    # authenticate_user! is already called by ApplicationTool#call
    
    normalized_exercise = exercise.strip.downcase
    
    last_set = current_user.set_entries
                          .where(exercise: normalized_exercise)
                          .order(timestamp: :desc)
                          .first
    
    if last_set
      {
        success: true,
        message: "Last #{exercise}: #{last_set.reps} reps at #{last_set.weight.to_f} lbs",
        last_set: {
          id: last_set.id,
          exercise: last_set.exercise,
          weight: last_set.weight.to_f,
          reps: last_set.reps,
          timestamp: last_set.timestamp.iso8601,
          logged_at: last_set.created_at.iso8601
        }
      }
    else
      # Check if user has any sets logged for similar exercises
      similar_exercises = current_user.set_entries
                                    .where("exercise LIKE ?", "%#{normalized_exercise.split.last}%")
                                    .distinct
                                    .pluck(:exercise)
      
      if similar_exercises.any?
        {
          success: false,
          message: "No sets found for '#{exercise}'. Did you mean one of these: #{similar_exercises.join(', ')}?",
          suggestions: similar_exercises
        }
      else
        {
          success: false,
          message: "No sets found for #{exercise}",
          available_exercises: current_user.set_entries.distinct.pluck(:exercise)
        }
      end
    end
  rescue => e
    {
      success: false,
      error: "Failed to retrieve last set: #{e.message}"
    }
  end
end