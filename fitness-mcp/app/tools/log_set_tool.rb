class LogSetTool < ApplicationTool
  description "Log a completed workout set with exercise, weight, and reps"
  
  arguments do
    required(:exercise).filled(:string).description("Name of the exercise (e.g., 'barbell squat', 'deadlift')")
    required(:weight).filled(:float).description("Weight used in pounds or kilograms")
    required(:reps).filled(:integer).description("Number of repetitions completed")
    optional(:timestamp).filled(:string).description("ISO timestamp of when set was completed (defaults to current time)")
  end
  
  def perform(exercise:, weight:, reps:, timestamp: nil)
    # authenticate_user! is already called by ApplicationTool#call
    
    parsed_timestamp = timestamp ? Time.parse(timestamp) : Time.current
    
    set_entry = current_user.set_entries.create!(
      exercise: exercise.strip.downcase,
      weight: weight,
      reps: reps,
      timestamp: parsed_timestamp
    )
    
    {
      success: true,
      message: "Successfully logged #{reps} reps of #{exercise} at #{weight} lbs",
      set_entry: {
        id: set_entry.id,
        exercise: set_entry.exercise,
        weight: set_entry.weight,
        reps: set_entry.reps,
        timestamp: set_entry.timestamp.iso8601
      }
    }
  rescue ActiveRecord::RecordInvalid => e
    {
      success: false,
      error: "Failed to log set: #{e.record.errors.full_messages.join(', ')}"
    }
  rescue ArgumentError => e
    {
      success: false,
      error: "Invalid timestamp format: #{e.message}"
    }
  end
end