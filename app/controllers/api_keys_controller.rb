class ApiKeysController < ApplicationController
  before_action :require_login
  
  def create
    api_key = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key)
    
    api_key_record = current_user.api_keys.build(
      name: api_key_params[:name],
      api_key_hash: key_hash,
      api_key_value: api_key
    )
    
    if api_key_record.save
      render json: { 
        success: true, 
        message: 'API key created successfully',
        api_key: {
          id: api_key_record.id,
          name: api_key_record.name,
          key: api_key,
          created_at: api_key_record.created_at
        }
      }
    else
      render json: { 
        success: false, 
        errors: api_key_record.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    api_key = current_user.api_keys.find(params[:id])
    api_key.destroy
    render json: { success: true, message: 'API key deleted successfully' }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'API key not found' }, status: :not_found
  end
  
  def revoke
    api_key = current_user.api_keys.find(params[:id])
    api_key.update!(revoked_at: Time.current)
    render json: { success: true, message: 'API key revoked successfully' }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'API key not found' }, status: :not_found
  end
  
  private
  
  def api_key_params
    params.require(:api_key).permit(:name)
  end
  
  def require_login
    unless session[:user_id]
      render json: { success: false, message: 'Please log in first' }, status: :unauthorized
    end
  end
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end