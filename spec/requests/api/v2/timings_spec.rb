require 'rails_helper'

RSpec.describe 'Api::V2::Timings', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/timings' do
    context 'when authenticated' do
      it 'returns 200 with all timings' do
        get '/api/v2/timings', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['timings'].size).to eq(3)
        expect(json['timings'].first).to include('id' => 1, 'name' => 'ドンピシャ')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/timings'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
