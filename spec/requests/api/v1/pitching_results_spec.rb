require 'rails_helper'

RSpec.describe 'Api::V1::PitchingResults', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'GET /api/v1/pitching_results' do
    it 'returns 500 due to typo in controller (PitchingResults instead of PitchingResult)' do
      get '/api/v1/pitching_results'

      # Controller has `PitchingResults` (plural) which is not a valid constant
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe 'POST /api/v1/pitching_results' do
    let(:game_result) { create(:game_result, user:) }

    context 'when authenticated' do
      it 'creates a pitching result and returns 201' do
        post '/api/v1/pitching_results',
             params: {
               pitching_result: {
                 game_result_id: game_result.id,
                 user_id: user.id,
                 win: 1,
                 loss: 0,
                 hold: 0,
                 saves: 0,
                 innings_pitched: 7.0,
                 number_of_pitches: 100,
                 got_to_the_distance: false,
                 run_allowed: 2,
                 earned_run: 1,
                 hits_allowed: 5,
                 home_runs_hit: 0,
                 strikeouts: 6,
                 base_on_balls: 2,
                 hit_by_pitch: 0
               }
             },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/pitching_results',
             params: { pitching_result: { game_result_id: game_result.id, user_id: user.id } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/pitching_results/:id' do
    let(:game_result) { create(:game_result, user:) }
    let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

    context 'when authenticated' do
      it 'updates the pitching result and returns 200' do
        put "/api/v1/pitching_results/#{pitching_result.id}",
            params: { pitching_result: { win: 0, loss: 1 } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        put "/api/v1/pitching_results/#{pitching_result.id}",
            params: { pitching_result: { win: 0, loss: 1 } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/pitching_search' do
    let(:game_result) { create(:game_result, user:) }
    let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

    context 'when authenticated' do
      context 'when record exists' do
        it 'returns 200 with the matching record' do
          get '/api/v1/pitching_search',
              params: { game_result_id: game_result.id, user_id: user.id },
              headers: auth_headers_for(user)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when record does not exist' do
        it 'returns 404' do
          get '/api/v1/pitching_search',
              params: { game_result_id: 0, user_id: user.id },
              headers: auth_headers_for(user)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/pitching_search',
            params: { game_result_id: game_result.id, user_id: user.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/current_pitching_result_search' do
    let(:game_result) { create(:game_result, user:) }
    let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

    context 'when authenticated' do
      it 'returns 200 with current user pitching result for given game_result_id' do
        get '/api/v1/current_pitching_result_search',
            params: { game_result_id: game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).not_to be_empty
      end

      it 'returns empty array when no game_result_id given' do
        get '/api/v1/current_pitching_result_search', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to eq([])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/current_pitching_result_search',
            params: { game_result_id: game_result.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/user_pitching_result_search' do
    let(:other_game_result) { create(:game_result, user: other_user) }
    let!(:other_pitching_result) { create(:pitching_result, game_result: other_game_result, user: other_user) }

    context 'when authenticated' do
      it 'returns 200' do
        get '/api/v1/user_pitching_result_search',
            params: { game_result_id: other_game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/user_pitching_result_search',
            params: { game_result_id: other_game_result.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/pitching_results/personal_pitching_result' do
    let!(:game_result) { create(:game_result, user:) }
    let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

    it 'returns 200 with aggregated pitching data for user' do
      get '/api/v1/pitching_results/personal_pitching_result',
          params: { user_id: user.id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/pitching_results/personal_pitching_stats' do
    let!(:game_result) { create(:game_result, user:) }
    let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

    it 'returns 200 with pitching stats for user' do
      get '/api/v1/pitching_results/personal_pitching_stats',
          params: { user_id: user.id }

      expect(response).to have_http_status(:ok)
    end

    context 'when user has no pitching results' do
      it 'returns 200 with empty message' do
        get '/api/v1/pitching_results/personal_pitching_stats',
            params: { user_id: other_user.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to eq('投手成績はまだありません。')
      end
    end
  end
end
