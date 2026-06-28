require 'rails_helper'

RSpec.describe 'Api::V2::PracticeMenuTrends', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  describe 'GET /api/v2/practice_menu_trends/:id' do
    it 'メニューの年別・月別・日別の集計を返す' do
      menu = create(:practice_menu, user:, name: 'ベンチプレス', unit: 'weight_reps', category: 'strength')
      create(:practice_log, user:, practice_menu: menu, logged_on: today, amount: 10, weight: 60)
      create(:practice_log, user:, practice_menu: menu, logged_on: today, amount: 8, weight: 70)

      get "/api/v2/practice_menu_trends/#{menu.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['menu']['is_weight_reps']).to be(true)
      expect(body['by_year'].first['period']).to eq(today.year.to_s)
      expect(body['by_month'].first['period']).to eq(today.strftime('%Y-%m'))
      expect(body['by_day'].first['period']).to eq(today.to_s)
      expect(body['by_day'].first['total_volume'].to_f).to eq((60 * 10) + (70 * 8))
    end

    it '他ユーザーのメニューは 404' do
      other = create(:practice_menu, user: create(:user))
      get "/api/v2/practice_menu_trends/#{other.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
