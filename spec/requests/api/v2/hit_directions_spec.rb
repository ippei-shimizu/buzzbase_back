require 'rails_helper'

RSpec.describe 'Api::V2::HitDirections', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/hit_directions' do
    context 'when authenticated' do
      it 'returns 200 with all 13 directions including zone_polygon' do
        get '/api/v2/hit_directions', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['hit_directions'].size).to eq(13)
        first = json['hit_directions'].first
        expect(first).to include('id' => 1, 'name' => '投')
        expect(first['zone_polygon']).to be_present
      end

      it '内野方向は depth: nil の単一polygon' do
        get '/api/v2/hit_directions', headers: auth_headers_for(user)
        infield = response.parsed_body['hit_directions'].find { |item| item['id'] == 1 }
        expect(infield['zone_polygon']).to include('depth' => nil)
        expect(infield['zone_polygon']['polygon']).to be_an(Array)
      end

      it '外野方向は depth_id 別の複数polygon (配列)' do
        get '/api/v2/hit_directions', headers: auth_headers_for(user)
        outfield = response.parsed_body['hit_directions'].find { |item| item['id'] == 10 }
        expect(outfield['zone_polygon']).to be_an(Array)
        expect(outfield['zone_polygon'].pluck('depth_id')).to contain_exactly(1, 2, 3)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/hit_directions'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
