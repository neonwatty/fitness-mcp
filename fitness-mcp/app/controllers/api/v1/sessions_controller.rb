class Api::V1::SessionsController < ApplicationController
  # Session management doesn't require API key authentication
  
  def create
    @user = User.find_by(email: session_params[:email])
    
    if @user&.authenticate(session_params[:password])
      # Generate a new API key for the session
      api_key = ApiKey.generate_key
      key_hash = ApiKey.hash_key(api_key)
      
      @api_key_record = @user.api_keys.create!(
        name: session_params[:name] || 'Session Key',
        api_key_hash: key_hash
      )
      
      render_success(
        {
          user: user_response(@user),
          api_key: api_key,
          key_name: @api_key_record.name
        },
        'Login successful'
      )
    else
      render_error('Invalid email or password', :unauthorized)
    end
  end
  
  def destroy
    # For logout, we need to authenticate to know which key to revoke
    authenticate_api_key!
    
    if @api_key_record
      @api_key_record.revoke!
      render_success({}, 'Logged out successfully')
    else
      render_error('No active session found', :unauthorized)
    end
  end
  
  private
  
  def session_params
    params.require(:session).permit(:email, :password, :name)
  end
  
  def user_response(user)
    {
      id: user.id,
      email: user.email
    }
  end
  
  def authenticate_api_key!
    return render_unauthorized unless api_key_header.present?
    
    key_hash = ApiKey.hash_key(api_key_header)
    @api_key_record = ApiKey.active.find_by(api_key_hash: key_hash)
    
    render_unauthorized unless @api_key_record
  end
  
  def api_key_header
    @api_key_header ||= request.headers['Authorization']&.gsub(/^Bearer\s+/, '')
  end
  
  def render_unauthorized
    render json: { error: 'Unauthorized. Please provide a valid API key in Authorization header.' }, status: :unauthorized
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