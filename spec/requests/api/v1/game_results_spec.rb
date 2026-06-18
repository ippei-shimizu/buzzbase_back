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

      it 'returns per-game batting_average.hit as NPB 標準の全安打 (単打 + 2B + 3B + HR)' do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2026, 5, 1))
        # 単打 1 + 2B 1 + HR 1 = 全安打 3
        create(:batting_average, game_result: gr, user:,
                                 hit: 1, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                                 at_bats: 4, total_bases: 7, times_at_bat: 4)

        get '/api/v1/game_results/game_associated_data_index', headers: auth_headers_for(user)

        json = response.parsed_body
        ba = json.first['batting_average']
        expect(ba['hit']).to eq(3)
        expect(ba['two_base_hit']).to eq(1)
        expect(ba['home_run']).to eq(1)
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
    context 'when authenticated' do
      it 'returns 200 when target user is public' do
        get '/api/v1/game_results/game_associated_data_index_user_id',
            params: { user_id: other_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end

      it 'returns per-game batting_average.hit as NPB 標準の全安打 for other user' do
        gr = create(:game_result, user: other_user)
        gr.match_result.update!(date_and_time: Time.zone.local(2026, 5, 1))
        # 単打 1 + 2B 1 + HR 1 = 全安打 3
        create(:batting_average, game_result: gr, user: other_user,
                                 hit: 1, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                                 at_bats: 4, total_bases: 7, times_at_bat: 4)

        get '/api/v1/game_results/game_associated_data_index_user_id',
            params: { user_id: other_user.id },
            headers: auth_headers_for(user)

        json = response.parsed_body
        ba = json.first['batting_average']
        expect(ba['hit']).to eq(3)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/game_results/game_associated_data_index_user_id', params: { user_id: other_user.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when target user is private' do
      let(:private_user) { create(:user, is_private: true) }

      it 'returns 401 for unauthenticated request' do
        get '/api/v1/game_results/game_associated_data_index_user_id', params: { user_id: private_user.id }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 403 when viewer is not a follower' do
        get '/api/v1/game_results/game_associated_data_index_user_id',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/game_results/filtered_game_associated_data_user_id' do
    context 'when authenticated' do
      it 'returns 200 when target user is public' do
        get '/api/v1/game_results/filtered_game_associated_data_user_id',
            params: { user_id: other_user.id, year: Time.current.year.to_s, match_type: '全て' },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/game_results/filtered_game_associated_data_user_id',
            params: { user_id: other_user.id, year: Time.current.year.to_s, match_type: '全て' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/game_results' do
    context 'when authenticated' do
      it 'creates a game result and returns 201' do
        post '/api/v1/game_results', headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
      end

      context 'when empty game results exist' do
        let!(:empty_game_result) do
          GameResult.create!(user:)
        end

        it 'deletes empty game results before creating a new one' do
          expect do
            post '/api/v1/game_results', headers: auth_headers_for(user)
          end.not_to change(GameResult, :count)

          expect(response).to have_http_status(:created)
          expect(GameResult.exists?(empty_game_result.id)).to be false
        end
      end

      context 'when game result has associated match_result' do
        let!(:complete_game_result) { create(:game_result, user:) }

        it 'does not delete game results with associations' do
          post '/api/v1/game_results', headers: auth_headers_for(user)

          expect(response).to have_http_status(:created)
          expect(GameResult.exists?(complete_game_result.id)).to be true
        end
      end

      context 'when game result has plate_appearances but no match_result' do
        let!(:partial_game_result) do
          gr = GameResult.create!(user:)
          create(:plate_appearance, game_result: gr, user:)
          gr
        end

        it 'does not delete game results with plate_appearances' do
          post '/api/v1/game_results', headers: auth_headers_for(user)

          expect(response).to have_http_status(:created)
          expect(GameResult.exists?(partial_game_result.id)).to be true
        end
      end

      context 'when other user has empty game results' do
        let!(:other_empty) { GameResult.create!(user: other_user) }

        it 'does not delete other users empty game results' do
          post '/api/v1/game_results', headers: auth_headers_for(user)

          expect(response).to have_http_status(:created)
          expect(GameResult.exists?(other_empty.id)).to be true
        end
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

    context 'when the game result does not exist (idempotent)' do
      it 'returns 200 with already-deleted message' do
        delete '/api/v1/game_results/999999', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to eq('試合結果は既に削除されています')
      end
    end

    context 'when the game result belongs to another user (idempotent)' do
      let(:other_user) { create(:user) }
      let!(:other_user_game_result) { create(:game_result, user: other_user) }

      it 'returns 200 without deleting the other user\'s record' do
        delete "/api/v1/game_results/#{other_user_game_result.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to eq('試合結果は既に削除されています')
        expect(GameResult.exists?(other_user_game_result.id)).to be true
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

      it 'returns per-game batting_average.hit as NPB 標準の全安打 in filtered result' do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2026, 5, 1), match_type: 'regular')
        # 単打 1 + 2B 1 + HR 1 = 全安打 3
        create(:batting_average, game_result: gr, user:,
                                 hit: 1, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                                 at_bats: 4, total_bases: 7, times_at_bat: 4)

        get '/api/v1/game_results/filtered_game_associated_data',
            params: { year: '2026', match_type: '全て' },
            headers: auth_headers_for(user)

        json = response.parsed_body
        ba = json.first['batting_average']
        expect(ba['hit']).to eq(3)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/game_results/filtered_game_associated_data',
            params: { year: Time.current.year.to_s, match_type: '全て' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
