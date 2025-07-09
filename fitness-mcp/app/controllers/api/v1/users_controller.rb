class Api::V1::UsersController < ApplicationController
  # User registration doesn't require authentication
  
  def create
    @user = User.new(user_params)
    
    if @user.save
      render_success(
        { user: user_response(@user) },
        'User created successfully'
      )
    else
      render_error(@user.errors.full_messages.join(', '))
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
  
  def user_response(user)
    {
      id: user.id,
      email: user.email,
      created_at: user.created_at.iso8601
    }
  end
  
  def authenticate_api_key!
    # Override to allow access to create action
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