class GetLastSetsTool < ApplicationTool
  description "Get the last N sets for a specific exercise"
  
  arguments do
    required(:exercise).filled(:string).description("Name of the exercise to query")
    optional(:limit).filled(:integer).description("Number of sets to retrieve (default: 5, max: 20)")
  end
  
  def perform(exercise:, limit: 5)
    # authenticate_user! is already called by ApplicationTool#call
    
    # Validate limit parameter
    limit = [[limit, 1].max, 20].min
    
    normalized_exercise = exercise.strip.downcase
    sets = current_user.set_entries
                      .where(exercise: normalized_exercise)
                      .order(timestamp: :desc)
                      .limit(limit)
    
    if sets.any?
      set_entries = sets.map do |set|
        {
          id: set.id,
          exercise: set.exercise,
          weight: set.weight.to_f,
          reps: set.reps,
          timestamp: set.timestamp.iso8601
        }
      end
      
      {
        success: true,
        count: sets.count,
        set_entries: set_entries,
        message: "Found #{sets.count} recent sets for #{exercise}"
      }
    else
      {
        success: false,
        message: "No sets found for #{exercise}"
      }
    end
  end
end