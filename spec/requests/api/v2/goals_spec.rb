require 'rails_helper'

RSpec.describe 'Api::V2::Goals', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/goals' do
    context '未認証' do
      it '401' do
        get '/api/v2/goals'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'アクティブな目標を進捗付きで返す' do
      create(:goal, user:, target_value: 20)
      create(:practice_log, :shadow_swing, user:, logged_on: today, amount: 100)
      get '/api/v2/goals', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      goal = response.parsed_body.first
      expect(goal).to have_key('progress_percent')
      expect(goal).to have_key('current_value')
      expect(goal['current_value']).to eq(1) # 当日の練習日数 = 1
    end
  end

  describe 'POST /api/v2/goals' do
    let(:params) do
      { goal: { title: '月20日', period_type: 'monthly', month_start: today.beginning_of_month,
                deadline: today.end_of_month, metric_key: 'practice_days', target_value: 20 } }
    end

    it '月次目標を作成する' do
      post '/api/v2/goals', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
    end

    context '無料ユーザーが月次3つ目' do
      before { create_list(:goal, 2, user:) }

      it '403' do
        post '/api/v2/goals', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'シーズン目標' do
      let(:season_params) do
        { goal: { title: 'season', period_type: 'season', deadline: today + 30,
                  metric_key: 'batting_average', target_value: 0.3 } }
      end

      it '無料は403' do
        post '/api/v2/goals', params: season_params, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'Pro は作成できる' do
        make_pro(user)
        post '/api/v2/goals', params: season_params, headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'FinalizeGoalsJob' do
    it '期限切れ目標を確定し達成ならバッジ付与' do
      goal = create(:goal, user:, deadline: today - 1, target_value: 1, metric_key: 'practice_days',
                           month_start: (today - 1).beginning_of_month)
      create(:activity_log, user:, activity_date: today - 1, intensity_level: 2)

      expect { FinalizeGoalsJob.new.perform }.to change { user.goal_badges.count }.by(1)
      expect(goal.reload.is_finalized).to be(true)
      expect(goal.is_achieved).to be(true)
    end
  end
end
