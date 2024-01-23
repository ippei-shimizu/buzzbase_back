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

      resources :positions, only: %i[index show]

      resources :user_positions, only: [:create]

      resources :teams, only: %i[index create update team_name] do
        member do
          get :team_name
        end
      end

      resources :baseball_categories, only: [:index]

      resources :prefectures, only: [:index]

      resources :match_results

      resources :tournaments, only: %i[index create update show]

      resources :game_results, only: %i[index create update]

      resources :batting_averages, only: %i[index create update]

      resources :plate_appearances, only: %i[create update]

      resources :pitching_results, only: %i[index create update]

      get 'users/current', to: 'users#show_current'
      get 'search', to: 'batting_averages#search'
      get 'existing_search', to: 'match_results#existing_search'
      get 'plate_search', to: 'plate_appearances#plate_search'
      get 'pitching_search', to: 'pitching_results#pitching_search'
      get 'current_game_result_search', to: 'match_results#current_game_result_search'
      get 'current_batting_average_search', to: 'batting_averages#current_batting_average_search'
      get 'current_pitching_result_search', to: 'pitching_results#current_pitching_result_search'
      get 'current_plate_search', to: 'plate_appearances#current_plate_search'
    end
  end

  devise_for :users, controllers: {
    confirmations: 'custom_confirmations'
  }
end
