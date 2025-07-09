class Api::V1::FitnessController < Api::V1::BaseController
  # Mirror the MCP tool functionality as REST endpoints
  
  def log_set
    set_entry = current_user.set_entries.build(
      exercise: fitness_params[:exercise].strip.downcase,
      weight: fitness_params[:weight],
      reps: fitness_params[:reps],
      timestamp: fitness_params[:timestamp] ? Time.parse(fitness_params[:timestamp]) : Time.current
    )
    
    if set_entry.save
      render_success(
        {
          set_entry: set_entry_response(set_entry)
        },
        "Successfully logged #{set_entry.reps} reps of #{set_entry.exercise} at #{set_entry.weight} lbs"
      )
    else
      render_error(set_entry.errors.full_messages.join(', '))
    end
  rescue ArgumentError => e
    render_error("Invalid timestamp format: #{e.message}")
  end
  
  def get_last_set
    normalized_exercise = params[:exercise].strip.downcase
    last_set = current_user.set_entries
                          .for_exercise(normalized_exercise)
                          .recent
                          .first
    
    if last_set
      render_success(
        {
          set_entry: set_entry_response(last_set)
        },
        "Last #{params[:exercise]}: #{last_set.reps} reps at #{last_set.weight} lbs on #{last_set.timestamp.strftime('%Y-%m-%d %H:%M')}"
      )
    else
      render_error("No sets found for #{params[:exercise]}", :not_found)
    end
  end
  
  def get_last_sets
    limit = [[params[:limit].to_i, 1].max, 20].min
    limit = 5 if limit == 0
    
    normalized_exercise = params[:exercise].strip.downcase
    sets = current_user.set_entries
                      .for_exercise(normalized_exercise)
                      .recent
                      .limit(limit)
    
    if sets.any?
      render_success(
        {
          count: sets.count,
          set_entries: sets.map { |set| set_entry_response(set) }
        },
        "Found #{sets.count} recent sets for #{params[:exercise]}"
      )
    else
      render_error("No sets found for #{params[:exercise]}", :not_found)
    end
  end
  
  def delete_last_set
    normalized_exercise = params[:exercise].strip.downcase
    last_set = current_user.set_entries
                          .for_exercise(normalized_exercise)
                          .recent
                          .first
    
    if last_set
      deleted_set = set_entry_response(last_set)
      last_set.destroy!
      
      render_success(
        {
          deleted_set: deleted_set
        },
        "Successfully deleted last #{params[:exercise]} set: #{deleted_set[:reps]} reps at #{deleted_set[:weight]} lbs"
      )
    else
      render_error("No sets found for #{params[:exercise]} to delete", :not_found)
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    render_error("Failed to delete set: #{e.message}")
  end
  
  def assign_workout
    exercises = params[:exercises]
    
    unless exercises.is_a?(Array) && exercises.all? { |ex| valid_exercise?(ex) }
      return render_error("Invalid exercises format. Each exercise must have 'name', 'sets', 'reps', and 'weight' fields.")
    end
    
    parsed_schedule = params[:scheduled_for] ? Time.parse(params[:scheduled_for]) : nil
    
    config = {
      exercises: exercises.map do |exercise|
        {
          name: exercise['name'].strip.downcase,
          sets: exercise['sets'].to_i,
          reps: exercise['reps'].to_i,
          weight: exercise['weight'].to_f
        }
      end
    }
    
    workout_assignment = current_user.workout_assignments.build(
      assignment_name: params[:assignment_name],
      config: config.to_json,
      scheduled_for: parsed_schedule
    )
    
    if workout_assignment.save
      render_success(
        {
          workout_assignment: workout_assignment_response(workout_assignment)
        },
        "Successfully created workout assignment '#{workout_assignment.assignment_name}'" + 
        (parsed_schedule ? " scheduled for #{parsed_schedule.strftime('%Y-%m-%d %H:%M')}" : "")
      )
    else
      render_error(workout_assignment.errors.full_messages.join(', '))
    end
  rescue ArgumentError => e
    render_error("Invalid timestamp format: #{e.message}")
  end
  
  private
  
  def fitness_params
    params.permit(:exercise, :weight, :reps, :timestamp)
  end
  
  def workout_params
    params.permit(:assignment_name, :scheduled_for, exercises: [:name, :sets, :reps, :weight])
  end
  
  def valid_exercise?(exercise)
    (exercise.is_a?(Hash) || exercise.is_a?(ActionController::Parameters)) &&
      exercise.key?('name') &&
      exercise.key?('sets') &&
      exercise.key?('reps') &&
      exercise.key?('weight') &&
      exercise['name'].present? &&
      exercise['sets'].to_i > 0 &&
      exercise['reps'].to_i > 0 &&
      exercise['weight'].to_f >= 0
  end
  
  def set_entry_response(set)
    {
      id: set.id,
      exercise: set.exercise,
      weight: set.weight,
      reps: set.reps,
      timestamp: set.timestamp.iso8601
    }
  end
  
  def workout_assignment_response(assignment)
    {
      id: assignment.id,
      assignment_name: assignment.assignment_name,
      exercises: assignment.config_json[:exercises] || JSON.parse(assignment.config)['exercises'],
      scheduled_for: assignment.scheduled_for&.iso8601
    }
  end
end