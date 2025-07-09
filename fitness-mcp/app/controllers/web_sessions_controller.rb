class WebSessionsController < ApplicationController
  def new
    # Login form
    render :new
  end
  
  def create
    @user = User.find_by(email: params[:email])
    
    if @user&.authenticate(params[:password])
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: 'Login successful!'
    else
      flash.now[:alert] = 'Invalid credentials'
      render :new
    end
  end
  
  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: 'Logout successful!'
  end
end