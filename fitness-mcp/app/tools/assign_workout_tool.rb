class AssignWorkoutTool < ApplicationTool
  description "Create and assign a workout plan with exercises and sets"
  
  arguments do
    required(:assignment_name).filled(:string).description("Name for the workout assignment")
    required(:exercises).filled(:array).description("Array of exercises with sets configuration")
    optional(:scheduled_for).filled(:string).description("ISO timestamp for when workout is scheduled")
  end
  
  def perform(assignment_name:, exercises:, scheduled_for: nil)
    # authenticate_user! is already called by ApplicationTool#call
    
    # Validate exercises structure
    unless exercises.is_a?(Array) && exercises.all? { |ex| valid_exercise?(ex) }
      return {
        success: false,
        error: "Invalid exercises format. Each exercise must have 'name', 'sets', 'reps', and 'weight' fields."
      }
    end
    
    parsed_schedule = scheduled_for ? Time.parse(scheduled_for) : nil
    
    config = {
      exercises: exercises.map do |exercise|
        # Support both string and symbol keys
        name = exercise['name'] || exercise[:name]
        sets = exercise['sets'] || exercise[:sets]
        reps = exercise['reps'] || exercise[:reps]
        weight = exercise['weight'] || exercise[:weight]
        
        {
          name: name.strip.downcase,
          sets: sets.to_i,
          reps: reps.to_i,
          weight: weight.to_f
        }
      end
    }
    
    workout_assignment = current_user.workout_assignments.create!(
      assignment_name: assignment_name,
      config: config.to_json,
      scheduled_for: parsed_schedule
    )
    
    {
      success: true,
      workout_assignment: {
        id: workout_assignment.id,
        assignment_name: workout_assignment.assignment_name,
        exercises: config[:exercises],
        scheduled_for: workout_assignment.scheduled_for&.iso8601
      },
      message: "Successfully created workout assignment '#{assignment_name}'" + 
               (parsed_schedule ? " scheduled for #{parsed_schedule.strftime('%Y-%m-%d %H:%M')}" : "")
    }
  rescue ActiveRecord::RecordInvalid => e
    {
      success: false,
      error: "Failed to create workout assignment: #{e.record.errors.full_messages.join(', ')}"
    }
  rescue ArgumentError => e
    {
      success: false,
      error: "Invalid timestamp format: #{e.message}"
    }
  end
  
  private
  
  def valid_exercise?(exercise)
    return false unless exercise.is_a?(Hash)
    
    # Support both string and symbol keys
    name = exercise['name'] || exercise[:name]
    sets = exercise['sets'] || exercise[:sets]
    reps = exercise['reps'] || exercise[:reps]
    weight = exercise['weight'] || exercise[:weight]
    
    name.present? &&
      sets.to_i > 0 &&
      reps.to_i > 0 &&
      weight.present? &&
      weight.to_f >= 0
  end
end