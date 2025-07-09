Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # User registration and authentication
      namespace :auth do
        post '/register', to: 'users#create'
        post '/login', to: 'sessions#create'
        delete '/logout', to: 'sessions#destroy'
      end
      
      # API key management
      resources :api_keys, only: [:index, :create, :destroy] do
        member do
          patch :revoke
        end
      end
      
      # Fitness tracking endpoints
      namespace :fitness do
        post '/log_set', to: 'fitness#log_set'
        get '/history', to: 'fitness#history'
        post '/create_plan', to: 'fitness#create_plan'
        get '/plans', to: 'fitness#plans'
        get '/get_last_set', to: 'fitness#get_last_set'
        get '/get_last_sets', to: 'fitness#get_last_sets'
        get '/get_recent_sets', to: 'fitness#get_recent_sets'
        delete '/delete_last_set', to: 'fitness#delete_last_set'
        post '/assign_workout', to: 'fitness#assign_workout'
      end
      
      # Additional endpoints for manual usage
      resources :set_entries, only: [:index, :show, :create, :update, :destroy]
      resources :workout_assignments, only: [:index, :show, :create, :update, :destroy]
    end
  end

  # Web interface routes
  root "home#index"
  get "/register", to: "web_users#new"
  post "/register", to: "web_users#create"
  get "/login", to: "web_sessions#new"
  post "/login", to: "web_sessions#create"
  delete "/logout", to: "web_sessions#destroy"
  get "/dashboard", to: "home#dashboard"
  
  # Web API key management
  resources :api_keys, only: [:create, :destroy] do
    member do
      patch :revoke
    end
  end
  
  # API info endpoint
  get "/api_info", to: "application#info"
end
