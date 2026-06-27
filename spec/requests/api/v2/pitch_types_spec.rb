require 'rails_helper'

RSpec.describe 'Api::V2::PitchTypes', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/pitch_types' do
    context 'when authenticated' do
      it 'returns 200 with all pitch types ordered by display_order' do
        get '/api/v2/pitch_types', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('pitch_types')
        expect(json['pitch_types'].size).to eq(10)
        expect(json['pitch_types'].first).to include('id' => 1, 'name' => 'ストレート系', 'display_order' => 1)
        expect(json['pitch_types'].pluck('display_order')).to eq((1..10).to_a)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/pitch_types'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
