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

    it 'メニューセット由来のメニューを展開し、その予定に紐づく当日ログ済みは done を立てる' do
      menu = create(:practice_menu, user:, name: '素振り')
      menu_set = create(:menu_set, user:, name: 'オフ日ルーティン')
      create(:menu_set_item, menu_set:, practice_menu: menu, target_value: 200)
      schedule = create(:schedule, user:, title: nil, menu_set:, days_of_week: '1', scheduled_time: '06:00')
      create(:practice_log, user:, practice_menu: menu, schedule:, logged_on: '2026-07-06', amount: 200)

      get '/api/v2/plans/by_date', params: { date: '2026-07-06' }, headers: auth_headers_for(user)

      plan = response.parsed_body.first
      expect(plan['title']).to eq('オフ日ルーティン')
      expect(plan['menus'].first['name']).to eq('素振り')
      expect(plan['menus'].first['done']).to be(true)
      expect(plan['done']).to be(true)
    end

    it '同じメニューを含む別の予定のログでは done を立てない（予定単位で独立）' do
      menu = create(:practice_menu, user:, name: '素振り')
      done_set = create(:menu_set, user:, name: '済セット')
      pending_set = create(:menu_set, user:, name: '未済セット')
      create(:menu_set_item, menu_set: done_set, practice_menu: menu, target_value: 200)
      create(:menu_set_item, menu_set: pending_set, practice_menu: menu, target_value: 100)
      done_schedule = create(:schedule, user:, title: nil, menu_set: done_set, days_of_week: '1', scheduled_time: '06:00')
      create(:schedule, user:, title: nil, menu_set: pending_set, days_of_week: '1', scheduled_time: '18:00')
      create(:practice_log, user:, practice_menu: menu, schedule: done_schedule, logged_on: '2026-07-06', amount: 200)

      get '/api/v2/plans/by_date', params: { date: '2026-07-06' }, headers: auth_headers_for(user)

      plans_by_title = response.parsed_body.index_by { |plan| plan['title'] }
      expect(plans_by_title['済セット']['menus'].first['done']).to be(true)
      expect(plans_by_title['未済セット']['menus'].first['done']).to be(false)
    end
  end

  describe 'GET /api/v2/plans/calendar' do
    it 'from/to が不正なら422' do
      get '/api/v2/plans/calendar', params: { from: '2026-07-10', to: '2026-07-01' }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '期間内の予定を日別エントリで返す' do
      # 無料の閲覧範囲クランプ(直近月中心)の影響を受けないようにする。日付自体はテスト対象外。
      make_pro(user)
      create(:schedule, user:, title: '朝練', days_of_week: '1', scheduled_time: '06:00')
      create(:schedule, user:, title: '試合', days_of_week: nil, planned_on: '2026-07-08', event_type: 'game')

      get '/api/v2/plans/calendar', params: { from: '2026-07-06', to: '2026-07-12' }, headers: auth_headers_for(user)

      entries = response.parsed_body['entries']
      dates = entries.pluck('date')
      expect(dates).to include('2026-07-06', '2026-07-08')
      game_entry = entries.find { |entry| entry['event_type'] == 'game' }
      expect(game_entry['title']).to eq('試合')
    end

    context '無料ユーザーの閲覧範囲(直近月中心)' do
      it '前後15日を超える未来の予定はクランプされて含まれない' do
        today = Time.zone.today
        far_future = today + 40
        create(:schedule, user:, title: '遠い未来の予定', days_of_week: nil, planned_on: far_future)

        get '/api/v2/plans/calendar',
            params: { from: today.iso8601, to: (far_future + 1).iso8601 },
            headers: auth_headers_for(user)

        dates = response.parsed_body['entries'].pluck('date')
        expect(dates).not_to include(far_future.iso8601)
      end

      it 'schedule_calendar_full_historyを持つProユーザーはクランプされない' do
        make_pro(user)
        today = Time.zone.today
        far_future = today + 40
        create(:schedule, user:, title: '遠い未来の予定', days_of_week: nil, planned_on: far_future)

        get '/api/v2/plans/calendar',
            params: { from: today.iso8601, to: (far_future + 1).iso8601 },
            headers: auth_headers_for(user)

        dates = response.parsed_body['entries'].pluck('date')
        expect(dates).to include(far_future.iso8601)
      end
    end
  end
end
