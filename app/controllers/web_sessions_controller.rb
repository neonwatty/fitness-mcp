class WebSessionsController < ApplicationController
  def new
    # Login form
    render :new
  end
  
  def create
    @user = User.find_by(email: params[:email])
    
    if @user.nil?
      flash.now[:alert] = 'Invalid email or password'
      render :new
    elsif @user.oauth_user? && !@user.has_password?
      flash.now[:alert] = 'This account uses Google sign-in. Please use the "Sign in with Google" button.'
      render :new
    elsif @user.authenticate(params[:password])
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: 'Login successful!'
    else
      flash.now[:alert] = 'Invalid email or password'
      render :new
    end
  end
  
  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: 'Logout successful!'
  end
end