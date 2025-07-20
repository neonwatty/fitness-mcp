class Api::V1::Auth::UsersController < Api::V1::BaseController
  skip_before_action :authenticate_api_key!, only: [:create]
  
  def create
    @user = User.new(user_params)
    
    if @user.save
      render json: {
        success: true,
        message: "User registered successfully",
        user: {
          id: @user.id,
          email: @user.email,
          created_at: @user.created_at
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: "Registration failed",
        errors: @user.errors
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end