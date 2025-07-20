class Api::V1::WorkoutAssignmentsController < Api::V1::BaseController
  before_action :find_workout_assignment, only: [:show, :update, :destroy]
  
  def index
    @assignments = current_user.workout_assignments.order(created_at: :desc)
    
    # Filter by scheduled status if provided
    @assignments = @assignments.scheduled if params[:scheduled] == 'true'
    @assignments = @assignments.upcoming if params[:upcoming] == 'true'
    
    # Pagination
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = [[params[:per_page].to_i, 1].max, 100].min
    per_page = 20 if per_page == 0
    
    @assignments = @assignments.offset((page - 1) * per_page).limit(per_page)
    
    render_success(
      {
        workout_assignments: @assignments.map { |assignment| workout_assignment_response(assignment) },
        pagination: {
          page: page,
          per_page: per_page,
          total: current_user.workout_assignments.count
        }
      }
    )
  end
  
  def show
    render_success(
      {
        workout_assignment: workout_assignment_response(@assignment)
      }
    )
  end
  
  def create
    @assignment = current_user.workout_assignments.build(workout_assignment_params)
    
    if @assignment.save
      render_success(
        {
          workout_assignment: workout_assignment_response(@assignment)
        },
        'Workout assignment created successfully'
      )
    else
      render_error(@assignment.errors.full_messages.join(', '))
    end
  end
  
  def update
    if @assignment.update(workout_assignment_params)
      render_success(
        {
          workout_assignment: workout_assignment_response(@assignment)
        },
        'Workout assignment updated successfully'
      )
    else
      render_error(@assignment.errors.full_messages.join(', '))
    end
  end
  
  def destroy
    if @assignment.destroy
      render_success({}, 'Workout assignment deleted successfully')
    else
      render_error('Failed to delete workout assignment')
    end
  end
  
  private
  
  def find_workout_assignment
    @assignment = current_user.workout_assignments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Workout assignment not found', :not_found)
  end
  
  def workout_assignment_params
    params.require(:workout_assignment).permit(:assignment_name, :scheduled_for, :config)
  end
  
  def workout_assignment_response(assignment)
    {
      id: assignment.id,
      assignment_name: assignment.assignment_name,
      config: assignment.config_json,
      scheduled_for: assignment.scheduled_for&.iso8601,
      created_at: assignment.created_at.iso8601,
      updated_at: assignment.updated_at.iso8601
    }
  end
end