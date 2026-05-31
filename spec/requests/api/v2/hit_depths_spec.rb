require 'rails_helper'

RSpec.describe 'Api::V2::HitDepths', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/hit_depths' do
    context 'when authenticated' do
      it 'returns 200 with all hit depths' do
        get '/api/v2/hit_depths', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['hit_depths'].size).to eq(3)
        expect(json['hit_depths'].first).to include('id' => 1, 'name' => '内野')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/hit_depths'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
