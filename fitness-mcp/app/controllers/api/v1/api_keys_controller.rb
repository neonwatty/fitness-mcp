class Api::V1::ApiKeysController < Api::V1::BaseController
  before_action :set_current_user
  def index
    api_keys = current_user.api_keys.active
    
    render json: {
      success: true,
      api_keys: api_keys.map { |key| api_key_response(key) }
    }
  end
  
  def create
    return render_name_required unless params[:name].present?
    
    api_key = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key)
    
    @api_key_record = current_user.api_keys.build(
      name: params[:name],
      api_key_hash: key_hash
    )
    
    if @api_key_record.save
      render json: {
        success: true,
        message: 'API Key created successfully',
        api_key: {
          id: @api_key_record.id,
          name: @api_key_record.name,
          key: api_key
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: @api_key_record.errors.full_messages.join(', ')
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @api_key_record = current_user.api_keys.find(params[:id])
    
    if @api_key_record.destroy
      render json: {
        success: true,
        message: 'API key deleted successfully'
      }
    else
      render json: {
        success: false,
        message: 'Failed to delete API key'
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'API Key not found'
    }, status: :not_found
  end
  
  def revoke
    @api_key_record = current_user.api_keys.find(params[:id])
    
    if @api_key_record.revoke!
      render_success({}, 'API key revoked successfully')
    else
      render_error('Failed to revoke API key')
    end
  rescue ActiveRecord::RecordNotFound
    render_error('API key not found', :not_found)
  end
  
  private
  
  def render_name_required
    render json: {
      success: false,
      message: 'Name is required'
    }, status: :bad_request
  end
  
  def api_key_params
    params.require(:api_key).permit(:name)
  end
  
  def api_key_response(key)
    {
      id: key.id,
      name: key.name,
      created_at: key.created_at.iso8601,
      revoked_at: key.revoked_at&.iso8601,
      active: key.active?
    }
  end
end