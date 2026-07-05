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

    context '大会目標' do
      let(:tournament) { create(:tournament) }
      let(:tournament_params) do
        { goal: { title: '大会で3割', period_type: 'tournament', tournament_id: tournament.id,
                  deadline: today + 7, metric_key: 'batting_average', target_value: 0.3 } }
      end

      it '無料は403' do
        post '/api/v2/goals', params: tournament_params, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'Pro は作成でき tournament_id を返す' do
        make_pro(user)
        post '/api/v2/goals', params: tournament_params, headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['tournament_id']).to eq(tournament.id)
      end

      it 'tournament_id が無いと作成できない' do
        make_pro(user)
        post '/api/v2/goals',
             params: { goal: tournament_params[:goal].except(:tournament_id) },
             headers: auth_headers_for(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context '週次・カスタム期間（日付レンジ系）' do
      it '週次目標を作成できる' do
        params = { goal: { title: '今週10日', period_type: 'weekly',
                           month_start: today.beginning_of_week, deadline: today.end_of_week,
                           metric_key: 'practice_days', target_value: 5 } }
        post '/api/v2/goals', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
      end

      it 'カスタム期間目標を作成できる' do
        params = { goal: { title: '大会前3週間', period_type: 'custom',
                           month_start: today, deadline: today + 21,
                           metric_key: 'total_swing_count', target_value: 2000 } }
        post '/api/v2/goals', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
      end

      it 'カスタムで終了日が開始日より前だと作成できない' do
        params = { goal: { title: '逆転', period_type: 'custom',
                           month_start: today, deadline: today - 1,
                           metric_key: 'practice_days', target_value: 5 } }
        post '/api/v2/goals', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it '無料枠は月次と共有（月次2件あると週次は403）' do
        create_list(:goal, 2, user:)
        params = { goal: { title: '今週', period_type: 'weekly',
                           month_start: today.beginning_of_week, deadline: today.end_of_week,
                           metric_key: 'practice_days', target_value: 5 } }
        post '/api/v2/goals', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v2/goals/:id' do
    it '更新で種類（period_type）は変更できない（Pro制限回避防止）' do
      goal = create(:goal, user:, period_type: 'monthly')
      patch "/api/v2/goals/#{goal.id}",
            params: { goal: { period_type: 'season', title: '変更' } },
            headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(goal.reload.period_type).to eq('monthly')
      expect(goal.title).to eq('変更')
    end
  end

  describe '定性目標（qualitative）' do
    it '指標・目標値なしで定性目標を作成できる' do
      params = { goal: { title: 'この大会で優勝', kind: 'qualitative', period_type: 'tournament',
                         tournament_id: create(:tournament).id, deadline: today + 7.days } }
      make_pro(user)
      post '/api/v2/goals', params:, headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body['kind']).to eq('qualitative')
        expect(body['metric_key']).to be_nil
        expect(body['progress_percent']).to eq(0.0)
      end
    end

    it 'POST achievement で達成にし progress_percent が100になる' do
      goal = create(:goal, :qualitative, user:)
      post "/api/v2/goals/#{goal.id}/achievement", headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['is_achieved']).to be true
        expect(response.parsed_body['progress_percent']).to eq(100.0)
        expect(goal.reload.is_achieved).to be true
      end
    end

    it 'DELETE achievement で達成を取り消す' do
      goal = create(:goal, :qualitative, user:, is_achieved: true)
      delete "/api/v2/goals/#{goal.id}/achievement", headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(goal.reload.is_achieved).to be false
      end
    end

    it '数値目標は手動達成できない（422）' do
      goal = create(:goal, user:)
      post "/api/v2/goals/#{goal.id}/achievement", headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe '継続目標（menu_practice_days）' do
    it '他ユーザーの練習メニューは指定できない（422）' do
      others_menu = create(:practice_menu, user: create(:user))
      params = { goal: { title: '素振り継続', period_type: 'monthly',
                         month_start: today.beginning_of_month, deadline: today.end_of_month,
                         metric_key: 'menu_practice_days', target_value: 20, practice_menu_id: others_menu.id } }
      post '/api/v2/goals', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe '自由指標（manual）' do
    it '指標名・現在値を持つ自由指標目標を作成し、手入力の現在値が進捗に反映される' do
      params = { goal: { title: '球速アップ', kind: 'manual', period_type: 'monthly',
                         month_start: today.beginning_of_month, deadline: today.end_of_month,
                         custom_metric_label: '球速', custom_unit: 'km/h',
                         target_value: 130, manual_current_value: 125, comparison_type: 'greater_than' } }
      post '/api/v2/goals', params:, headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body['kind']).to eq('manual')
        expect(body['custom_metric_label']).to eq('球速')
        expect(body['current_value']).to eq(125.0)
        expect(body['progress_percent']).to eq(96.2)
      end
    end

    it '指標名が無いと作成できない（422）' do
      params = { goal: { title: '球速', kind: 'manual', period_type: 'monthly',
                         month_start: today.beginning_of_month, deadline: today.end_of_month, target_value: 130 } }
      post '/api/v2/goals', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
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
