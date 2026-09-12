require 'rails_helper'

RSpec.describe 'Api::V2::ArmAngles', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/arm_angles' do
    context 'when authenticated' do
      it 'returns 200 with seeded masters in display_order' do
        get '/api/v2/arm_angles', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        names = response.parsed_body['arm_angles'].pluck('name')
        expect(names).to eq(%w[オーバースロー スリークォーター サイドスロー アンダースロー])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/arm_angles'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
