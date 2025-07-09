class Api::V1::Fitness::FitnessController < Api::V1::BaseController
  before_action :set_current_user
  def log_set
    return render_error("Exercise is required", :bad_request) unless params[:exercise].present?
    return render_error("Weight is required", :bad_request) unless params[:weight].present?
    return render_error("Reps is required", :bad_request) unless params[:reps].present?
    
    @set_entry = @current_user.set_entries.build(
      exercise: params[:exercise],
      weight: params[:weight].to_f,
      reps: params[:reps].to_i,
      timestamp: params[:timestamp] || Time.current
    )
    
    if @set_entry.save
      render json: {
        success: true,
        message: "Set logged successfully",
        set: {
          id: @set_entry.id,
          exercise: @set_entry.exercise,
          weight: @set_entry.weight.to_f,
          reps: @set_entry.reps.to_i,
          timestamp: @set_entry.timestamp
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: @set_entry.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end
  
  def history
    @sets = @current_user.set_entries.recent
    
    if params[:exercise].present?
      @sets = @sets.for_exercise(params[:exercise])
    end
    
    if params[:limit].present?
      @sets = @sets.limit(params[:limit].to_i)
    end
    
    render json: {
      success: true,
      history: @sets.map do |set|
        {
          id: set.id,
          exercise: set.exercise,
          weight: set.weight.to_f,
          reps: set.reps.to_i,
          timestamp: set.timestamp
        }
      end
    }
  end
  
  def create_plan
    return render_error("Assignment name is required", :bad_request) unless params[:assignment_name].present?
    return render_error("Scheduled for is required", :bad_request) unless params[:scheduled_for].present?
    return render_error("Exercises are required", :bad_request) unless params[:exercises].present?
    
    @assignment = @current_user.workout_assignments.build(
      assignment_name: params[:assignment_name],
      scheduled_for: params[:scheduled_for],
      config: {
        exercises: params[:exercises]
      }.to_json
    )
    
    if @assignment.save
      render json: {
        success: true,
        message: "Workout plan created successfully",
        plan: {
          id: @assignment.id,
          assignment_name: @assignment.assignment_name,
          scheduled_for: @assignment.scheduled_for,
          config: @assignment.config
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: @assignment.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end
  
  def plans
    @assignments = @current_user.workout_assignments.upcoming
    
    render json: {
      success: true,
      plans: @assignments.map do |assignment|
        {
          id: assignment.id,
          assignment_name: assignment.assignment_name,
          scheduled_for: assignment.scheduled_for,
          config: assignment.config,
          created_at: assignment.created_at
        }
      end
    }
  end
  
  def get_last_set
    return render json: { success: false, message: "Exercise is required" }, status: :bad_request unless params[:exercise].present?
    
    normalized_exercise = params[:exercise].strip.downcase
    @set = @current_user.set_entries.where("LOWER(exercise) = ?", normalized_exercise).recent.limit(1).first
    
    if @set
      render json: {
        success: true,
        set: {
          id: @set.id,
          exercise: @set.exercise,
          weight: @set.weight,
          reps: @set.reps,
          timestamp: @set.timestamp
        }
      }
    else
      render json: {
        success: false,
        message: "No sets found"
      }, status: :not_found
    end
  end
  
  def get_last_sets
    return render json: { success: false, message: "Exercise is required" }, status: :bad_request unless params[:exercise].present?
    
    limit = params[:limit] || 10
    normalized_exercise = params[:exercise].strip.downcase
    @sets = @current_user.set_entries.where("LOWER(exercise) = ?", normalized_exercise).recent.limit(limit.to_i)
    
    render json: {
      success: true,
      sets: @sets.map do |set|
        {
          id: set.id,
          exercise: set.exercise,
          weight: set.weight,
          reps: set.reps,
          timestamp: set.timestamp
        }
      end
    }
  end
  
  def get_recent_sets
    limit = params[:limit] || 10
    @sets = @current_user.set_entries.recent.limit(limit.to_i)
    
    render json: {
      success: true,
      sets: @sets.map do |set|
        {
          id: set.id,
          exercise: set.exercise,
          weight: set.weight,
          reps: set.reps,
          timestamp: set.timestamp
        }
      end
    }
  end
  
  def delete_last_set
    @set = @current_user.set_entries.recent.limit(1).first
    
    if @set
      @set.destroy
      render json: {
        success: true,
        message: "Last set deleted successfully"
      }
    else
      render json: {
        success: false,
        message: "No sets found to delete"
      }, status: :not_found
    end
  end
  
  def assign_workout
    return render_error("Assignment name is required", :bad_request) unless params[:assignment_name].present?
    return render_error("Scheduled for is required", :bad_request) unless params[:scheduled_for].present?
    return render_error("Config is required", :bad_request) unless params[:config].present?
    
    @assignment = @current_user.workout_assignments.build(
      assignment_name: params[:assignment_name],
      scheduled_for: params[:scheduled_for],
      config: params[:config].to_json
    )
    
    if @assignment.save
      render json: {
        success: true,
        message: "Workout assigned successfully",
        assignment: {
          id: @assignment.id,
          assignment_name: @assignment.assignment_name,
          scheduled_for: @assignment.scheduled_for,
          config: @assignment.config
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: @assignment.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def render_error(message, status)
    render json: {
      success: false,
      message: message
    }, status: status
  end
end