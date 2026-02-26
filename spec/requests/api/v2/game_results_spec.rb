require 'rails_helper'

RSpec.describe 'Api::V2::GameResults', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let!(:user_game) { create(:game_result, user: user) }
  let!(:other_user_game) { create(:game_result, user: other_user) }

  describe 'GET /api/v2/game_results' do
    context 'when authenticated' do
      it 'returns 200 with only the current user game results' do
        get '/api/v2/game_results', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        game_result_ids = json.map { |r| r['game_result_id'] }
        expect(game_result_ids).to include(user_game.id)
        expect(game_result_ids).not_to include(other_user_game.id)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/game_results'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v2/game_results/all' do
    it 'returns 200 with game results for all users' do
      get '/api/v2/game_results/all'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      game_result_ids = json.map { |r| r['game_result_id'] }
      expect(game_result_ids).to include(user_game.id, other_user_game.id)
    end

    it 'includes user information in each result' do
      get '/api/v2/game_results/all'

      json = JSON.parse(response.body)
      first_result = json.first
      expect(first_result).to have_key('user_id')
      expect(first_result).to have_key('user_name')
      expect(first_result).to have_key('user_image')
      expect(first_result).to have_key('user_user_id')
    end
  end

  describe 'GET /api/v2/game_results/filtered_index' do
    let!(:game_2024_regular) do
      gr = create(:game_result, user: user)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 15), match_type: 'regular')
      gr
    end
    let!(:game_2024_open) do
      gr = create(:game_result, user: user)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 8, 20), match_type: 'open')
      gr
    end

    context 'when authenticated' do
      it 'returns 200 with filtered results by year and match_type' do
        get '/api/v2/game_results/filtered_index',
            params: { year: '2024', match_type: '公式戦' },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        game_result_ids = json.map { |r| r['game_result_id'] }
        expect(game_result_ids).to include(game_2024_regular.id)
        expect(game_result_ids).not_to include(game_2024_open.id)
      end

      it 'returns all results when year is "通算" and match_type is "全て"' do
        get '/api/v2/game_results/filtered_index',
            params: { year: '通算', match_type: '全て' },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        game_result_ids = json.map { |r| r['game_result_id'] }
        expect(game_result_ids).to include(user_game.id, game_2024_regular.id, game_2024_open.id)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/game_results/filtered_index', params: { year: '2024', match_type: '公式戦' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v2/game_results/user/:user_id' do
    it 'returns 200 with the specified user game results' do
      get "/api/v2/game_results/user/#{other_user.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      game_result_ids = json.map { |r| r['game_result_id'] }
      expect(game_result_ids).to include(other_user_game.id)
      expect(game_result_ids).not_to include(user_game.id)
    end
  end

  describe 'GET /api/v2/game_results/filtered_user/:user_id' do
    let!(:target_game_regular) do
      gr = create(:game_result, user: other_user)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 7, 10), match_type: 'regular')
      gr
    end
    let!(:target_game_open) do
      gr = create(:game_result, user: other_user)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 9, 5), match_type: 'open')
      gr
    end

    it 'returns 200 with filtered results by year and match_type' do
      get "/api/v2/game_results/filtered_user/#{other_user.id}",
          params: { year: '2024', match_type: 'オープン戦' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      game_result_ids = json.map { |r| r['game_result_id'] }
      expect(game_result_ids).to include(target_game_open.id)
      expect(game_result_ids).not_to include(target_game_regular.id)
    end
  end
end
