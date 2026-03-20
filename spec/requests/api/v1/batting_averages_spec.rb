require 'rails_helper'

RSpec.describe 'Api::V1::BattingAverages', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'GET /api/v1/batting_averages' do
    it 'returns 200 with all batting averages' do
      get '/api/v1/batting_averages'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/batting_averages' do
    let(:game_result) { create(:game_result, user:) }

    context 'when authenticated' do
      it 'creates a batting average and returns 201' do
        post '/api/v1/batting_averages',
             params: {
               batting_average: {
                 game_result_id: game_result.id,
                 user_id: user.id,
                 plate_appearances: 4,
                 times_at_bat: 4,
                 at_bats: 3,
                 hit: 1,
                 two_base_hit: 0,
                 three_base_hit: 0,
                 home_run: 0,
                 total_bases: 1,
                 runs_batted_in: 0,
                 run: 0,
                 strike_out: 1,
                 base_on_balls: 0,
                 hit_by_pitch: 0,
                 sacrifice_hit: 0,
                 sacrifice_fly: 0,
                 stealing_base: 0,
                 caught_stealing: 0,
                 error: 0
               }
             },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/batting_averages',
             params: { batting_average: { game_result_id: game_result.id, user_id: user.id } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/batting_averages/:id' do
    let(:game_result) { create(:game_result, user:) }
    let!(:batting_average) { create(:batting_average, game_result:, user:) }

    context 'when authenticated' do
      it 'updates the batting average and returns 200' do
        put "/api/v1/batting_averages/#{batting_average.id}",
            params: { batting_average: { hit: 2 } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        put "/api/v1/batting_averages/#{batting_average.id}",
            params: { batting_average: { hit: 2 } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/search (batting_averages#search)' do
    let(:game_result) { create(:game_result, user:) }
    let!(:batting_average) { create(:batting_average, game_result:, user:) }

    context 'when authenticated' do
      context 'when record exists' do
        it 'returns 200 with the matching record' do
          get '/api/v1/search',
              params: { game_result_id: game_result.id, user_id: user.id },
              headers: auth_headers_for(user)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when record does not exist' do
        it 'returns 404' do
          get '/api/v1/search',
              params: { game_result_id: 0, user_id: user.id },
              headers: auth_headers_for(user)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/search',
            params: { game_result_id: game_result.id, user_id: user.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/current_batting_average_search' do
    let(:game_result) { create(:game_result, user:) }
    let!(:batting_average) { create(:batting_average, game_result:, user:) }

    context 'when authenticated' do
      it 'returns 200 with current user batting average for given game_result_id' do
        get '/api/v1/current_batting_average_search',
            params: { game_result_id: game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).not_to be_empty
      end

      it 'returns empty array when no game_result_id given' do
        get '/api/v1/current_batting_average_search', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to eq([])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/current_batting_average_search',
            params: { game_result_id: game_result.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/batting_averages/personal_batting_average' do
    let!(:game_result) { create(:game_result, user:) }
    let!(:batting_average) { create(:batting_average, game_result:, user:) }

    it 'returns 200 with aggregated batting data for user' do
      get '/api/v1/batting_averages/personal_batting_average',
          params: { user_id: user.id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/batting_averages/personal_batting_stats' do
    let!(:game_result) { create(:game_result, user:) }
    let!(:batting_average) { create(:batting_average, game_result:, user:) }

    it 'returns 200 with batting stats for user' do
      get '/api/v1/batting_averages/personal_batting_stats',
          params: { user_id: user.id }

      expect(response).to have_http_status(:ok)
    end

    context 'when user has no batting averages' do
      it 'returns stats (may be empty/zero)' do
        get '/api/v1/batting_averages/personal_batting_stats',
            params: { user_id: other_user.id }

        # stats_for_user returns a hash even when no data exists
        expect(response).to have_http_status(:ok).or have_http_status(:not_found)
      end
    end
  end
end
