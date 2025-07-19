class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :google_oauth2
  
  def google_oauth2
    auth = request.env['omniauth.auth']
    user = User.from_omniauth(auth)
    
    if user.persisted?
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: 'Successfully signed in with Google!'
    else
      redirect_to login_path, alert: 'There was an error signing you in. Please try again.'
    end
  rescue StandardError => e
    Rails.logger.error "OAuth error: #{e.message}"
    redirect_to login_path, alert: 'Authentication failed. Please try again.'
  end
  
  def failure
    redirect_to login_path, alert: "Authentication failed: #{params[:message].humanize}"
  end
end