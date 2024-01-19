Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  namespace :api do
    namespace :v1 do
      mount_devise_token_auth_for 'User', at: 'auth', controllers: {}

      namespace :auth do
        resources :sessions, only: [:index]
      end

      resource :user, only: %i[update show] do
        put :update_positions
      end

      resources :users do
        resources :awards, only: %i[create index destroy update]
      end

      resources :positions, only: [:index]

      resources :user_positions, only: [:create]

      resources :teams, only: %i[index create update]

      resources :baseball_categories, only: [:index]

      resources :prefectures, only: [:index]

      resources :match_results

      resources :tournaments, only: %i[index create update]
    end
  end

  devise_for :users, controllers: {
    confirmations: 'custom_confirmations'
  }
end
