Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "conversations#index"

  resources :conversations, only: [ :index, :show, :create ] do
    resources :messages, only: [ :create ]
  end

  resources :ideas do
    member do
      patch :archive
      patch :unarchive
    end
    resources :investigations, only: [ :create, :show ] do
      member do
        post :distil
      end
    end
  end
end
