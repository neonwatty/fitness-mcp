class HomeController < ApplicationController
  def index
    # Show API info and links to registration/login
    render :index
  end
  
  def dashboard
    unless session[:user_id]
      redirect_to login_path, alert: 'Please log in first'
      return
    end
    
    @user = User.find(session[:user_id])
    @api_keys = @user.api_keys.active
    @recent_sets = @user.set_entries.recent.limit(5)
    @workout_assignments = @user.workout_assignments.order(created_at: :desc).limit(3)
    render :dashboard
  end
end