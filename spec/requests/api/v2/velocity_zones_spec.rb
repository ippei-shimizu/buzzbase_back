require 'rails_helper'

RSpec.describe 'Api::V2::VelocityZones', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/velocity_zones' do
    context 'when authenticated' do
      it 'returns 200 with seeded masters in display_order' do
        get '/api/v2/velocity_zones', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        names = response.parsed_body['velocity_zones'].pluck('name')
        expect(names).to eq(['120km/h未満', '120-130km/h', '130-140km/h', '140-150km/h', '150km/h以上'])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/velocity_zones'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
