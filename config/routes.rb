Rails.application.routes.draw do
  delete "/logout", to: "sessions#destroy", as: :logout
  get "/login", to: "static_pages#login", as: :login
  root "static_pages#home", as: :root
  post "/auth/hack_club", as: :hack_club_auth
  get "/auth/hack_club/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
