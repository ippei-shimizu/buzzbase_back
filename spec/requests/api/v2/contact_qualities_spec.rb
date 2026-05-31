require 'rails_helper'

RSpec.describe 'Api::V2::ContactQualities', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/contact_qualities' do
    context 'when authenticated' do
      it 'returns 200 with all contact qualities ordered by display_order' do
        get '/api/v2/contact_qualities', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('contact_qualities')
        expect(json['contact_qualities'].size).to eq(5)
        expect(json['contact_qualities'].first).to include('id' => 1, 'name' => '真芯')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/contact_qualities'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
