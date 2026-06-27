require 'rails_helper'

RSpec.describe 'Api::V2::PracticeMenus', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/practice_menus' do
    context '未認証' do
      it '401' do
        get '/api/v2/practice_menus'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '認証済み' do
      before do
        create(:practice_menu, user:, name: '素振り')
        create(:practice_menu, user:, name: '削除済み', archived: true)
      end

      it 'archived を除いた自分のメニューを返す' do
        get '/api/v2/practice_menus', headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        names = response.parsed_body.pluck('name')
        expect(names).to include('素振り')
        expect(names).not_to include('削除済み')
      end
    end
  end

  describe 'POST /api/v2/practice_menus' do
    let(:params) do
      { practice_menu: { name: 'ティー', category: 'batting', unit: 'count', unit_label: '球', default_value: 150 } }
    end

    it '作成できる' do
      post '/api/v2/practice_menus', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('ティー')
    end

    context '無料ユーザーが上限(5)を超える' do
      before { create_list(:practice_menu, 5, user:) }

      it '403 を返す' do
        post '/api/v2/practice_menus', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'Pro ユーザーは上限を超えて作成できる' do
      before do
        make_pro(user)
        create_list(:practice_menu, 5, user:)
      end

      it '201' do
        post '/api/v2/practice_menus', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'DELETE /api/v2/practice_menus/:id' do
    let!(:menu) { create(:practice_menu, user:) }

    it '論理削除（archived）する' do
      delete "/api/v2/practice_menus/#{menu.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(menu.reload.archived).to be(true)
    end
  end
end
