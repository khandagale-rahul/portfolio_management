Rails.application.routes.draw do
  resources :instrument_histories
  resources :holdings, only: [:index, :show]
  resources :instruments, only: [:index]
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :api_configurations

  # Upstox OAuth routes
  namespace :upstox do
    post 'oauth/authorize/:id', to: 'oauth#authorize', as: 'oauth_authorize'
    get 'oauth/callback', to: 'oauth#callback', as: 'oauth_callback'
  end

  # Zerodha OAuth routes
  namespace :zerodha do
    post 'oauth/authorize/:id', to: 'oauth#authorize', as: 'oauth_authorize'
    get 'oauth/callback', to: 'oauth#callback', as: 'oauth_callback'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
end
