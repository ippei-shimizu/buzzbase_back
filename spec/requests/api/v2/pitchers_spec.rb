require 'rails_helper'

RSpec.describe 'Api::V2::Pitchers', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:arm_angle) { ArmAngle.first }

  describe 'GET /api/v2/pitchers' do
    before do
      Pitcher.create!(name: '田中投手', throw_hand: :right, created_by_user: user)
      Pitcher.create!(name: '佐藤投手', throw_hand: :left, created_by_user: user)
      Pitcher.create!(name: '別ユーザー投手', throw_hand: :right, created_by_user: other_user)
    end

    context 'when authenticated' do
      it 'current user が作成した投手のみ返す（他ユーザー分は除外）' do
        get '/api/v2/pitchers', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        names = response.parsed_body['data'].pluck('name')
        expect(names).to include('田中投手', '佐藤投手')
        expect(names).not_to include('別ユーザー投手')
      end

      it 'q パラメータで部分一致検索ができる' do
        get '/api/v2/pitchers', params: { q: '田中' }, headers: auth_headers_for(user)
        names = response.parsed_body['data'].pluck('name')
        expect(names).to eq(['田中投手'])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/pitchers'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v2/pitchers' do
    let(:payload) do
      {
        pitcher: {
          name: '新規投手',
          throw_hand: 'right',
          arm_angle_id: arm_angle.id
        }
      }
    end

    it '投手を作成し、created_by_user は current_api_v1_user に固定される' do
      expect do
        post '/api/v2/pitchers', params: payload, headers: auth_headers_for(user), as: :json
      end.to change(Pitcher, :count).by(1)

      expect(response).to have_http_status(:created)
      created = Pitcher.find(response.parsed_body['id'])
      expect(created.created_by_user).to eq(user)
      expect(created.throw_hand).to eq('right')
    end

    it 'クライアントが created_by_user_id を渡しても無視される' do
      malicious = payload.deep_merge(pitcher: { created_by_user_id: other_user.id })
      post '/api/v2/pitchers', params: malicious, headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:created)
      created = Pitcher.find(response.parsed_body['id'])
      expect(created.created_by_user).to eq(user)
    end

    it 'name が空ならバリデーションエラー' do
      post '/api/v2/pitchers', params: { pitcher: { name: '' } }, headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).not_to be_empty
    end
  end

  describe 'PATCH /api/v2/pitchers/:id' do
    let!(:own_pitcher) { Pitcher.create!(name: '自分の投手', throw_hand: :right, created_by_user: user) }
    let!(:other_pitcher) { Pitcher.create!(name: '他人の投手', throw_hand: :right, created_by_user: other_user) }

    it '自分の投手の属性を更新できる' do
      patch "/api/v2/pitchers/#{own_pitcher.id}",
            params: { pitcher: { name: '更新後', throw_hand: 'left', memo: '配球メモ' } },
            headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      own_pitcher.reload
      expect(own_pitcher.name).to eq('更新後')
      expect(own_pitcher.throw_hand).to eq('left')
      expect(own_pitcher.memo).to eq('配球メモ')
    end

    it '他ユーザーが作成した投手は更新できず 404' do
      patch "/api/v2/pitchers/#{other_pitcher.id}",
            params: { pitcher: { name: '改ざん' } },
            headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_pitcher.reload.name).to eq('他人の投手')
    end
  end
end
