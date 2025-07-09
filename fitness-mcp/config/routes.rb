Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # User registration and authentication
      post '/users', to: 'users#create'
      post '/sessions', to: 'sessions#create'
      delete '/sessions', to: 'sessions#destroy'
      
      # API key management
      resources :api_keys, only: [:index, :create, :destroy] do
        member do
          patch :revoke
        end
      end
      
      # Fitness tracking endpoints
      post '/log_set', to: 'fitness#log_set'
      get '/get_last_set', to: 'fitness#get_last_set'
      get '/get_last_sets', to: 'fitness#get_last_sets'
      delete '/delete_last_set', to: 'fitness#delete_last_set'
      post '/assign_workout', to: 'fitness#assign_workout'
      
      # Additional endpoints for manual usage
      resources :set_entries, only: [:index, :show, :create, :update, :destroy]
      resources :workout_assignments, only: [:index, :show, :create, :update, :destroy]
    end
  end

  # Defines the root path route ("/")
  root "application#info"
end
