class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_key!
  
  protected
  
  def authenticate_api_key!
    return render_unauthorized unless api_key_header.present?
    
    key_hash = ApiKey.hash_key(api_key_header)
    @api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    
    render_unauthorized unless @api_key_record
  end
  
  def current_user
    @current_user ||= @api_key_record&.user
  end
  
  def set_current_user
    @current_user = current_user
  end
  
  def api_key_header
    @api_key_header ||= request.headers['Authorization']&.gsub(/^Bearer\s+/, '')
  end
  
  def render_unauthorized
    render json: { 
      success: false, 
      message: 'Missing or invalid API key' 
    }, status: :unauthorized
  end
  
  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end
  
  def render_success(data = {}, message = nil)
    response = { success: true }
    response[:message] = message if message
    response.merge!(data)
    render json: response
  end
end