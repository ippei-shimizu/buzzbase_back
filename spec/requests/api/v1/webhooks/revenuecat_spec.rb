require 'rails_helper'

RSpec.describe 'Api::V1::Webhooks::Revenuecat', type: :request do
  describe 'POST /api/v1/webhooks/revenuecat' do
    it 'returns 200 without authentication (signature handling is deferred to #318)' do
      post '/api/v1/webhooks/revenuecat', params: { event: { type: 'INITIAL_PURCHASE' } }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
