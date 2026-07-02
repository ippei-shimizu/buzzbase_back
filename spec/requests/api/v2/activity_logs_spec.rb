require 'rails_helper'

RSpec.describe 'Api::V2::ActivityLogs', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/activity_logs' do
    context '未認証' do
      it '401' do
        get '/api/v2/activity_logs'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '認証済み' do
      before do
        create(:activity_log, user:, activity_date: today, intensity_level: 2)
        create(:activity_log, user:, activity_date: today - 1, intensity_level: 1)
      end

      it 'ヒートマップデータと streak を返す' do
        get '/api/v2/activity_logs', headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['current_streak_days']).to eq(2)
        expect(body['data'].size).to eq(2)
      end
    end

    context '無料ユーザーが31日以上前を要求' do
      before do
        create(:activity_log, user:, activity_date: today)
        create(:activity_log, user:, activity_date: today - 40)
      end

      it '直近30日にクランプされ古いデータは含まれない' do
        get '/api/v2/activity_logs', params: { from: (today - 60).to_s }, headers: auth_headers_for(user)
        dates = response.parsed_body['data'].pluck('activity_date')
        expect(dates).to include(today.to_s)
        expect(dates).not_to include((today - 40).to_s)
      end
    end

    context 'Pro ユーザー' do
      before do
        make_pro(user)
        create(:activity_log, user:, activity_date: today - 40)
      end

      it '全期間を取得できる' do
        get '/api/v2/activity_logs', params: { from: (today - 60).to_s }, headers: auth_headers_for(user)
        dates = response.parsed_body['data'].pluck('activity_date')
        expect(dates).to include((today - 40).to_s)
      end
    end
  end

  describe 'GET /api/v2/activity_logs/streak' do
    before do
      create(:activity_log, user:, activity_date: today)
      create(:activity_log, user:, activity_date: today - 1)
      create(:activity_log, user:, activity_date: today - 2)
    end

    it '現在/最長/通算を返す' do
      get '/api/v2/activity_logs/streak', headers: auth_headers_for(user)
      body = response.parsed_body
      expect(body['current_streak_days']).to eq(3)
      expect(body['longest_streak_days']).to eq(3)
      expect(body['total_active_days']).to eq(3)
    end
  end

  describe '試合作成時の活動反映' do
    it '試合を作ると当日の activity_log に has_game が立つ' do
      create(:game_result, user:)
      activity_log = user.activity_logs.find_by(activity_date: today)
      expect(activity_log.has_game).to be(true)
      expect(activity_log.intensity_level).to eq(4)
    end
  end
end
