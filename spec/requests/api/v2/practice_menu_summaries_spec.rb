require 'rails_helper'

RSpec.describe 'Api::V2::PracticeMenuSummaries', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  describe 'GET /api/v2/practice_menu_summaries' do
    context '未認証' do
      it '401' do
        get '/api/v2/practice_menu_summaries'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'メニュー別に累計・今月・記録日数を返す' do
      menu = create(:practice_menu, user:, name: '素振り', unit: 'count', unit_label: '本')
      create(:practice_log, user:, practice_menu: menu, logged_on: today, amount: 100)
      create(:practice_log, user:, practice_menu: menu, logged_on: today - 40, amount: 200)

      get '/api/v2/practice_menu_summaries', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      summary = response.parsed_body.find { |item| item['menu_name'] == '素振り' }
      expect(summary['total_amount'].to_f).to eq(300.0)
      expect(summary['this_month_amount'].to_f).to eq(100.0)
      expect(summary['days_count']).to eq(2)
      expect(summary['last_logged_on']).to eq(today.to_s)
    end

    it '筋トレは総挙上重量（重さ×回数の合計）を返す' do
      menu = create(:practice_menu, user:, name: 'ベンチプレス', category: 'strength',
                                    unit: 'weight_reps', unit_label: '回')
      create(:practice_log, user:, practice_menu: menu, logged_on: today, amount: 10, weight: 60)
      create(:practice_log, user:, practice_menu: menu, logged_on: today, amount: 8, weight: 70)

      get '/api/v2/practice_menu_summaries', headers: auth_headers_for(user)
      summary = response.parsed_body.find { |item| item['menu_name'] == 'ベンチプレス' }
      expect(summary['total_volume'].to_f).to eq((60 * 10) + (70 * 8))
    end
  end
end
