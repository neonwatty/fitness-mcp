class GetRecentSetsTool < ApplicationTool
  description "Get the most recent N sets across all exercises"
  
  arguments do
    optional(:limit).filled(:integer).description("Number of sets to retrieve (default: 10, max: 50)")
  end
  
  def perform(limit: 10)
    # Validate limit parameter
    limit = [[limit, 1].max, 50].min
    
    sets = current_user.set_entries
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
        message: "Found #{sets.count} recent sets across all exercises"
      }
    else
      {
        success: false,
        message: "No sets found"
      }
    end
  end
end