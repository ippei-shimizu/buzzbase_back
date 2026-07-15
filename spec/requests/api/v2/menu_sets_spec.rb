require 'rails_helper'

RSpec.describe 'Api::V2::MenuSets', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/menu_sets' do
    context '未認証' do
      it '401' do
        get '/api/v2/menu_sets'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '所有するメニューセットを sort_order 順で返す' do
      create(:menu_set, user:, name: 'B', sort_order: 1)
      create(:menu_set, user:, name: 'A', sort_order: 0)
      create(:menu_set, user: create(:user), name: '他人のセット')

      get '/api/v2/menu_sets', headers: auth_headers_for(user)

      names = response.parsed_body.pluck('name')
      expect(names).to eq(%w[A B])
    end
  end

  describe 'POST /api/v2/menu_sets' do
    let(:menu) { create(:practice_menu, user:) }
    let(:params) do
      { menu_set: { name: 'オフ日ルーティン', items: [{ practice_menu_id: menu.id, target_value: 200 }] } }
    end

    it 'items 付きで作成する' do
      post '/api/v2/menu_sets', params:, headers: auth_headers_for(user)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['name']).to eq('オフ日ルーティン')
      expect(body['items'].first['practice_menu_id']).to eq(menu.id)
    end

    it '他ユーザーのメニューは紐付けられない（IDOR防止）' do
      other_menu = create(:practice_menu, user: create(:user))
      post '/api/v2/menu_sets',
           params: { menu_set: { name: 'x', items: [{ practice_menu_id: other_menu.id }] } },
           headers: auth_headers_for(user)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['items']).to be_empty
    end

    it '無料は3つまで。4つ目は403で拒否する' do
      create_list(:menu_set, 3, user:)
      post '/api/v2/menu_sets', params: { menu_set: { name: '4つ目' } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Pro は4つ目以降も作成できる' do
      create_list(:menu_set, 3, user:)
      make_pro(user)
      post '/api/v2/menu_sets', params: { menu_set: { name: '4つ目' } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/v2/menu_sets/:id' do
    it 'items を差し替える' do
      menu_set = create(:menu_set, user:, name: '旧')
      menu = create(:practice_menu, user:)

      patch "/api/v2/menu_sets/#{menu_set.id}",
            params: { menu_set: { name: '新', items: [{ practice_menu_id: menu.id, target_value: 50 }] } },
            headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['name']).to eq('新')
      expect(body['items'].size).to eq(1)
    end
  end

  describe 'DELETE /api/v2/menu_sets/:id' do
    it '削除する' do
      menu_set = create(:menu_set, user:)
      delete "/api/v2/menu_sets/#{menu_set.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(MenuSet.exists?(menu_set.id)).to be(false)
    end

    it '他ユーザーのセットは削除できない（404）' do
      other_set = create(:menu_set, user: create(:user))
      delete "/api/v2/menu_sets/#{other_set.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
