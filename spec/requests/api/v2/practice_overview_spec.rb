require 'rails_helper'

RSpec.describe 'Api::V2::PracticeOverview', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  describe 'GET /api/v2/practice_overview' do
    it '未認証は 401' do
      get '/api/v2/practice_overview'
      expect(response).to have_http_status(:unauthorized)
    end

    it '全体KPIを返す' do
      menu = create(:practice_menu, user:)
      strength = create(:practice_menu, user:, unit: 'weight_reps', category: 'strength')
      create(:practice_log, user:, practice_menu: menu, logged_on: today, amount: 100)
      create(:practice_log, :shadow_swing, user:, logged_on: today, amount: 50)
      create(:practice_log, user:, practice_menu: strength, logged_on: today - 40, amount: 10, weight: 60)

      get '/api/v2/practice_overview', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['total_practice_days']).to eq(2)
      expect(body['this_month_practice_days']).to eq(1)
      expect(body['total_swing_count']).to eq(50)
      expect(body['total_volume'].to_f).to eq(600.0)
      expect(body['total_menus']).to eq(2)
    end
  end
end
