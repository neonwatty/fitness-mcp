class DeleteLastSetTool < ApplicationTool
  description "Delete the most recent set for a specific exercise"
  
  arguments do
    required(:exercise).filled(:string).description("Name of the exercise to delete the last set for")
  end
  
  def perform(exercise:)
    # authenticate_user! is already called by ApplicationTool#call
    
    begin
      normalized_exercise = exercise.strip.downcase
      
      # Find the last set for this exercise
      last_set = current_user.set_entries
                            .where(exercise: normalized_exercise)
                            .order(timestamp: :desc)
                            .first
      
      if last_set
        # Capture set data before deletion
        deleted_set = {
          id: last_set.id,
          exercise: last_set.exercise,
          weight: last_set.weight.to_f,
          reps: last_set.reps,
          timestamp: last_set.timestamp.iso8601
        }
        
        # Delete the set
        last_set.destroy!
        
        {
          success: true,
          deleted_set: deleted_set,
          message: "Successfully deleted last #{exercise} set: #{deleted_set[:reps]} reps at #{deleted_set[:weight]} lbs"
        }
      else
        # Check for similar exercises to provide helpful suggestions
        similar_exercises = current_user.set_entries
                                      .where("exercise LIKE ?", "%#{normalized_exercise.split.last}%")
                                      .distinct
                                      .pluck(:exercise)
        
        if similar_exercises.any?
          {
            success: false,
            message: "No sets found for '#{exercise}' to delete. Did you mean one of these: #{similar_exercises.join(', ')}?",
            suggestions: similar_exercises
          }
        else
          {
            success: false,
            message: "No sets found for '#{exercise}' to delete.",
            available_exercises: current_user.set_entries.distinct.pluck(:exercise)
          }
        end
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      {
        success: false,
        error: "Failed to delete set: #{e.message}"
      }
    rescue => e
      {
        success: false,
        error: "An error occurred: #{e.message}"
      }
    end
  end
end