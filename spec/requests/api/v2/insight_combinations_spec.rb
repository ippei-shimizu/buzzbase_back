require 'rails_helper'

RSpec.describe 'Api::V2::InsightCombinations', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'POST /api/v2/insight_combinations' do
    let(:params) { { insight_combination: { input_type: 'sleep_hours', metric: 'ops' } } }

    it '未認証は401' do
      post('/api/v2/insight_combinations', params:)
      expect(response).to have_http_status(:unauthorized)
    end

    it '無料ユーザーは403' do
      post '/api/v2/insight_combinations', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Pro は作成できる' do
      make_pro(user)
      post '/api/v2/insight_combinations', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
    end

    it '他ユーザーのメニューは指定できない（IDOR防止）' do
      make_pro(user)
      others_menu = create(:practice_menu, user: create(:user))
      post '/api/v2/insight_combinations',
           params: { insight_combination: { input_type: 'practice_menu', practice_menu_id: others_menu.id, metric: 'ops' } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'Pro でも上限を超えると作成できない' do
      make_pro(user)
      pairs = Insights::Catalog::FIXED_INPUT_KEYS.product(Insights::Catalog::METRIC_KEYS)
      pairs.first(PlanLimits::INSIGHT_COMBINATION_LIMIT).each do |input_type, metric|
        create(:insight_combination, user:, input_type:, metric:)
      end
      extra_input, extra_metric = pairs[PlanLimits::INSIGHT_COMBINATION_LIMIT]
      post '/api/v2/insight_combinations',
           params: { insight_combination: { input_type: extra_input, metric: extra_metric } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v2/insight_combinations/:id' do
    it '自分の組み合わせを削除できる' do
      make_pro(user)
      combo = create(:insight_combination, user:)
      delete "/api/v2/insight_combinations/#{combo.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(InsightCombination.exists?(combo.id)).to be false
    end
  end
end
