require 'rails_helper'

RSpec.describe 'Api::V2::Plans', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/plans/by_date' do
    context '未認証' do
      it '401' do
        get '/api/v2/plans/by_date', params: { date: '2026-07-06' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'date が不正なら422' do
      get '/api/v2/plans/by_date', params: { date: 'invalid' }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '当日の繰り返しと単発の予定を集約して返す' do
      # 2026-07-06 は月曜（曜日番号1）
      create(:schedule, user:, title: '朝練', days_of_week: '1', scheduled_time: '06:00')
      create(:schedule, user:, title: '別日', days_of_week: '2', scheduled_time: '06:00')
      create(:schedule, user:, title: '試合', days_of_week: nil, planned_on: '2026-07-06',
                        scheduled_time: '09:00', event_type: 'game')

      get '/api/v2/plans/by_date', params: { date: '2026-07-06' }, headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      titles = response.parsed_body.pluck('title')
      expect(titles).to contain_exactly('朝練', '試合')
    end

    it '時刻順（未設定は末尾）で並ぶ' do
      create(:schedule, user:, title: '午後', days_of_week: '1', scheduled_time: '15:00')
      create(:schedule, user:, title: '朝', days_of_week: '1', scheduled_time: '06:00')
      create(:schedule, user:, title: '終日', days_of_week: '1', scheduled_time: nil, event_type: 'game')

      get '/api/v2/plans/by_date', params: { date: '2026-07-06' }, headers: auth_headers_for(user)

      expect(response.parsed_body.pluck('title')).to eq(%w[朝 午後 終日])
    end

    it 'メニューセット由来のメニューを展開し、当日ログ済みは done を立てる' do
      menu = create(:practice_menu, user:, name: '素振り')
      menu_set = create(:menu_set, user:, name: 'オフ日ルーティン')
      create(:menu_set_item, menu_set:, practice_menu: menu, target_value: 200)
      create(:schedule, user:, title: nil, menu_set:, days_of_week: '1', scheduled_time: '06:00')
      create(:practice_log, user:, practice_menu: menu, logged_on: '2026-07-06', amount: 200)

      get '/api/v2/plans/by_date', params: { date: '2026-07-06' }, headers: auth_headers_for(user)

      plan = response.parsed_body.first
      expect(plan['title']).to eq('オフ日ルーティン')
      expect(plan['menus'].first['name']).to eq('素振り')
      expect(plan['menus'].first['done']).to be(true)
      expect(plan['done']).to be(true)
    end
  end

  describe 'GET /api/v2/plans/calendar' do
    it 'from/to が不正なら422' do
      get '/api/v2/plans/calendar', params: { from: '2026-07-10', to: '2026-07-01' }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '期間内の予定を日別エントリで返す' do
      create(:schedule, user:, title: '朝練', days_of_week: '1', scheduled_time: '06:00')
      create(:schedule, user:, title: '試合', days_of_week: nil, planned_on: '2026-07-08', event_type: 'game')

      get '/api/v2/plans/calendar', params: { from: '2026-07-06', to: '2026-07-12' }, headers: auth_headers_for(user)

      entries = response.parsed_body['entries']
      dates = entries.pluck('date')
      expect(dates).to include('2026-07-06', '2026-07-08')
      game_entry = entries.find { |entry| entry['event_type'] == 'game' }
      expect(game_entry['title']).to eq('試合')
    end
  end
end
