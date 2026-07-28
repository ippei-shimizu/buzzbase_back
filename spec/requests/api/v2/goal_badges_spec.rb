require 'rails_helper'

RSpec.describe 'Api::V2::GoalBadges', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  describe 'GET /api/v2/goal_badges' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/goal_badges'
      expect(response).to have_http_status(:unauthorized)
    end

    it '自分のバッジを新しい順で返す' do
      goal = create(:goal, user:)
      older = create(:goal_badge, user:, goal:, badge_name: '月間目標達成', awarded_at: 2.days.ago)
      newer = create(:goal_badge, user:, goal:, badge_name: 'シーズン目標達成', awarded_at: 1.day.ago)

      get('/api/v2/goal_badges', headers:)
      expect(response).to have_http_status(:ok)
      badge_ids = response.parsed_body.pluck('id')
      expect(badge_ids).to eq([newer.id, older.id])
    end

    it '他ユーザーのバッジは含まれない' do
      other_user = create(:user)
      other_goal = create(:goal, user: other_user)
      create(:goal_badge, user: other_user, goal: other_goal)

      get('/api/v2/goal_badges', headers:)
      expect(response.parsed_body).to eq([])
    end

    it 'goal_titleにバッジの元になった目標のタイトルを含む' do
      goal = create(:goal, user:, title: '今月20日練習')
      create(:goal_badge, user:, goal:)

      get('/api/v2/goal_badges', headers:)
      expect(response.parsed_body.first['goal_title']).to eq('今月20日練習')
    end
  end
end
