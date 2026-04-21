require 'rails_helper'

RSpec.describe 'Api::V1::MatchResults', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:other_game_result) { create(:game_result, user: other_user) }

  describe 'GET /api/v1/match_index_user_id' do
    context 'when authenticated' do
      it 'returns 200 when target user is public' do
        get '/api/v1/match_index_user_id',
            params: { user_id: other_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/match_index_user_id',
            params: { user_id: other_user.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when target user is private' do
      let(:private_user) { create(:user, is_private: true) }

      it 'returns 403 when viewer is not a follower' do
        get '/api/v1/match_index_user_id',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/user_game_result_search' do
    context 'when authenticated' do
      it 'returns 200' do
        get '/api/v1/user_game_result_search',
            params: { game_result_id: other_game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok).or have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/user_game_result_search',
            params: { game_result_id: other_game_result.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when target user is private' do
      let(:private_user) { create(:user, is_private: true) }
      let!(:private_game_result) { create(:game_result, user: private_user) }

      it 'returns 403 when viewer is not a follower' do
        get '/api/v1/user_game_result_search',
            params: { game_result_id: private_game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
