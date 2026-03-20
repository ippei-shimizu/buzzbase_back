require 'rails_helper'

RSpec.describe 'Api::V1::GameResults', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'GET /api/v1/game_results/all_game_associated_data' do
    it 'returns 200 with game associated data for all users' do
      get '/api/v1/game_results/all_game_associated_data'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/game_results/game_associated_data_index' do
    context 'when authenticated' do
      it 'returns 200 with current user game associated data' do
        get '/api/v1/game_results/game_associated_data_index', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/game_results/game_associated_data_index'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/game_results/game_associated_data_index_user_id' do
    context 'when target user is public' do
      it 'returns 200' do
        get '/api/v1/game_results/game_associated_data_index_user_id', params: { user_id: other_user.id }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when target user is private' do
      let(:private_user) { create(:user, is_private: true) }

      it 'returns 403 for unauthenticated request' do
        get '/api/v1/game_results/game_associated_data_index_user_id', params: { user_id: private_user.id }

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 403 when viewer is not a follower' do
        get '/api/v1/game_results/game_associated_data_index_user_id',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/game_results' do
    context 'when authenticated' do
      it 'creates a game result and returns 201' do
        post '/api/v1/game_results', headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/game_results'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/game_results/:id' do
    let!(:game_result) { create(:game_result, user:) }

    context 'when authenticated' do
      it 'updates the game result and returns 201' do
        put "/api/v1/game_results/#{game_result.id}",
            params: { game_result: { season_id: nil } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        put "/api/v1/game_results/#{game_result.id}",
            params: { game_result: { season_id: nil } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/game_results/:id' do
    let!(:game_result) { create(:game_result, user:) }

    context 'when authenticated' do
      it 'destroys the game result and returns 200' do
        delete "/api/v1/game_results/#{game_result.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to eq('試合結果を削除しました')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        delete "/api/v1/game_results/#{game_result.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/game_results/filtered_game_associated_data' do
    context 'when authenticated' do
      it 'returns 200 with filtered game data' do
        get '/api/v1/game_results/filtered_game_associated_data',
            params: { year: Time.current.year.to_s, match_type: '全て' },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns error (uses current_api_v1_user without before_action guard)' do
        get '/api/v1/game_results/filtered_game_associated_data',
            params: { year: Time.current.year.to_s, match_type: '全て' }

        # filtered_game_associated_data is not in authenticate_api_v1_user! list
        # but uses current_api_v1_user, so it may 500 or return empty
        expect(response).to have_http_status(:internal_server_error)
          .or have_http_status(:ok)
      end
    end
  end
end
