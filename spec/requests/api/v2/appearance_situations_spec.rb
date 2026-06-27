require 'rails_helper'

RSpec.describe 'Api::V2::AppearanceSituations', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/appearance_situations' do
    context 'when authenticated' do
      it 'returns 200 with seeded masters in display_order' do
        get '/api/v2/appearance_situations', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        names = response.parsed_body['appearance_situations'].pluck('name')
        expect(names).to eq(%w[先発 中継ぎ 抑え])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/appearance_situations'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
