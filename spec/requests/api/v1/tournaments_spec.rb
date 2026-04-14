require 'rails_helper'

RSpec.describe 'Api::V1::Tournaments', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'GET /api/v1/tournaments/user_tournaments' do
    let!(:tournament_a) { create(:tournament, name: '春季大会') }
    let!(:tournament_b) { create(:tournament, name: '秋季大会') }
    let!(:tournament_other) { create(:tournament, name: '他ユーザー大会') }

    before do
      game_result_a = create(:game_result, user:)
      game_result_a.match_result.update!(tournament: tournament_a)

      game_result_b = create(:game_result, user:)
      game_result_b.match_result.update!(tournament: tournament_b)

      game_result_other = create(:game_result, user: other_user)
      game_result_other.match_result.update!(tournament: tournament_other)
    end

    context 'when authenticated' do
      it 'ログインユーザーの試合に紐づく大会のみ返す' do
        get '/api/v1/tournaments/user_tournaments',
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        names = json.pluck('name')
        expect(names).to include('春季大会', '秋季大会')
        expect(names).not_to include('他ユーザー大会')
      end

      it '大会名でソートされている' do
        get '/api/v1/tournaments/user_tournaments',
            headers: auth_headers_for(user)

        json = response.parsed_body
        names = json.pluck('name')
        expect(names).to eq(names.sort)
      end

      it '重複なく返す' do
        game_result_dup = create(:game_result, user:)
        game_result_dup.match_result.update!(tournament: tournament_a)

        get '/api/v1/tournaments/user_tournaments',
            headers: auth_headers_for(user)

        json = response.parsed_body
        ids = json.pluck('id')
        expect(ids.uniq.size).to eq(ids.size)
      end
    end

    context 'when user_id is specified' do
      it '指定ユーザーの大会を返す' do
        get '/api/v1/tournaments/user_tournaments',
            params: { user_id: other_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        names = json.pluck('name')
        expect(names).to include('他ユーザー大会')
        expect(names).not_to include('春季大会', '秋季大会')
      end

      it '存在しないuser_idで404を返す' do
        get '/api/v1/tournaments/user_tournaments',
            params: { user_id: 999_999 },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json['error']).to eq('ユーザーが存在しません')
      end

      it '非公開アカウントのuser_idで403を返す' do
        private_user = create(:user, is_private: true)
        game_result_private = create(:game_result, user: private_user)
        game_result_private.match_result.update!(tournament: tournament_a)

        get '/api/v1/tournaments/user_tournaments',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json['error']).to eq('このアカウントは非公開です')
      end

      it '非公開アカウントでもフォロワーはアクセスできる' do
        private_user = create(:user, is_private: true)
        game_result_private = create(:game_result, user: private_user)
        game_result_private.match_result.update!(tournament: tournament_a)
        user.follow(private_user, force_accept: true)

        get '/api/v1/tournaments/user_tournaments',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/tournaments/user_tournaments'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/tournaments' do
    it '全大会を返す' do
      create(:tournament, name: '春季大会')
      create(:tournament, name: '秋季大会')

      get '/api/v1/tournaments'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(2)
    end
  end
end
