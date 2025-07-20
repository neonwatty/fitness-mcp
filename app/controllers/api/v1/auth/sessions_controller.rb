class Api::V1::Auth::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate_api_key!, only: [:create]
  
  def create
    user = User.find_by(email: params[:email])
    
    if user && user.authenticate(params[:password])
      render json: {
        success: true,
        message: "Login successful",
        user: {
          id: user.id,
          email: user.email,
          created_at: user.created_at
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: "Invalid credentials"
      }, status: :unauthorized
    end
  end
  
  def destroy
    render json: {
      success: true,
      message: "Logout successful"
    }, status: :ok
  end
end