class Api::V1::SetEntriesController < Api::V1::BaseController
  before_action :find_set_entry, only: [:show, :update, :destroy]
  
  def index
    @set_entries = current_user.set_entries.recent
    
    # Filter by exercise if provided
    @set_entries = @set_entries.for_exercise(params[:exercise]) if params[:exercise].present?
    
    # Pagination
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = [[params[:per_page].to_i, 1].max, 100].min
    per_page = 20 if per_page == 0
    
    @set_entries = @set_entries.offset((page - 1) * per_page).limit(per_page)
    
    render_success(
      {
        set_entries: @set_entries.map { |entry| set_entry_response(entry) },
        pagination: {
          page: page,
          per_page: per_page,
          total: current_user.set_entries.count
        }
      }
    )
  end
  
  def show
    render_success(
      {
        set_entry: set_entry_response(@set_entry)
      }
    )
  end
  
  def create
    @set_entry = current_user.set_entries.build(set_entry_params)
    
    if @set_entry.save
      render_success(
        {
          set_entry: set_entry_response(@set_entry)
        },
        'Set entry created successfully'
      )
    else
      render_error(@set_entry.errors.full_messages.join(', '))
    end
  end
  
  def update
    if @set_entry.update(set_entry_params)
      render_success(
        {
          set_entry: set_entry_response(@set_entry)
        },
        'Set entry updated successfully'
      )
    else
      render_error(@set_entry.errors.full_messages.join(', '))
    end
  end
  
  def destroy
    if @set_entry.destroy
      render_success({}, 'Set entry deleted successfully')
    else
      render_error('Failed to delete set entry')
    end
  end
  
  private
  
  def find_set_entry
    @set_entry = current_user.set_entries.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Set entry not found', :not_found)
  end
  
  def set_entry_params
    params.require(:set_entry).permit(:exercise, :weight, :reps, :timestamp)
  end
  
  def set_entry_response(entry)
    {
      id: entry.id,
      exercise: entry.exercise,
      weight: entry.weight,
      reps: entry.reps,
      timestamp: entry.timestamp.iso8601,
      created_at: entry.created_at.iso8601,
      updated_at: entry.updated_at.iso8601
    }
  end
end