class Api::V1::ApiKeysController < Api::V1::BaseController
  def index
    api_keys = current_user.api_keys.active
    
    render_success(
      {
        api_keys: api_keys.map { |key| api_key_response(key) }
      }
    )
  end
  
  def create
    api_key = ApiKey.generate_key
    key_hash = ApiKey.hash_key(api_key)
    
    @api_key_record = current_user.api_keys.build(
      name: api_key_params[:name],
      api_key_hash: key_hash
    )
    
    if @api_key_record.save
      render_success(
        {
          api_key: api_key,
          key_info: api_key_response(@api_key_record)
        },
        'API key created successfully'
      )
    else
      render_error(@api_key_record.errors.full_messages.join(', '))
    end
  end
  
  def destroy
    @api_key_record = current_user.api_keys.find(params[:id])
    
    if @api_key_record.destroy
      render_success({}, 'API key deleted successfully')
    else
      render_error('Failed to delete API key')
    end
  rescue ActiveRecord::RecordNotFound
    render_error('API key not found', :not_found)
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