require 'rails_helper'

RSpec.describe 'Api::V2::CorrelationInsights', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/correlation_insights' do
    context '未認証' do
      it '401' do
        get '/api/v2/correlation_insights'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '無料ユーザーは 403' do
      get '/api/v2/correlation_insights', headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Pro ユーザーはインサイトカードを取得できる' do
      make_pro(user)
      get '/api/v2/correlation_insights', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['insights']).to be_an(Array)
      expect(response.parsed_body['insights'].first).to include('key', 'title', 'sufficient')
    end
  end
end
