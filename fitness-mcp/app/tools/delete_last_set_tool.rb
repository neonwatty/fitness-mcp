class DeleteLastSetTool < ApplicationTool
  description "Delete the most recent set for a specific exercise"
  
  arguments do
    required(:exercise).filled(:string).description("Name of the exercise to delete the last set for")
  end
  
  def call(exercise:)
    authenticate_user!
    
    normalized_exercise = exercise.strip.downcase
    last_set = current_user.set_entries
                          .for_exercise(normalized_exercise)
                          .recent
                          .first
    
    if last_set
      deleted_set = {
        id: last_set.id,
        exercise: last_set.exercise,
        weight: last_set.weight,
        reps: last_set.reps,
        timestamp: last_set.timestamp.iso8601
      }
      
      last_set.destroy!
      
      {
        success: true,
        deleted_set: deleted_set,
        message: "Successfully deleted last #{exercise} set: #{deleted_set[:reps]} reps at #{deleted_set[:weight]} lbs"
      }
    else
      {
        success: false,
        message: "No sets found for #{exercise} to delete"
      }
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    {
      success: false,
      error: "Failed to delete set: #{e.message}"
    }
  end
end