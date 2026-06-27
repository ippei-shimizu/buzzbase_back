require 'rails_helper'

RSpec.describe 'Api::V2::ConditionLogs', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'POST /api/v2/condition_logs/upsert' do
    let(:params) do
      { condition_log: { logged_on: today, fatigue_level: 3, physical_level: 4, sleep_hours: 7.5, mood: '好調',
                         injuries: [{ part: '右肩', memo: '軽い張り' }] } }
    end

    context '無料ユーザー' do
      it '403（Pro 限定）' do
        post '/api/v2/condition_logs/upsert', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'Pro ユーザー' do
      before { make_pro(user) }

      it '作成できる' do
        post '/api/v2/condition_logs/upsert', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['mood']).to eq('好調')
      end

      it '同日は upsert（更新）になる' do
        create(:condition_log, user:, logged_on: today, mood: '不調')
        expect do
          post '/api/v2/condition_logs/upsert', params:, headers: auth_headers_for(user)
        end.not_to(change { user.condition_logs.count })
        expect(user.condition_logs.find_by(logged_on: today).mood).to eq('好調')
      end
    end
  end

  describe 'GET /api/v2/condition_logs/by_date' do
    before { make_pro(user) }

    it '当日の記録を返す' do
      create(:condition_log, user:, logged_on: today, mood: '普通')
      get '/api/v2/condition_logs/by_date', params: { date: today.to_s }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['mood']).to eq('普通')
    end
  end
end
