require 'rails_helper'

RSpec.describe 'Api::V2::PitcherStyles', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/pitcher_styles' do
    context 'when authenticated' do
      it 'returns 200 with seeded masters in display_order' do
        get '/api/v2/pitcher_styles', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        names = response.parsed_body['pitcher_styles'].pluck('name')
        expect(names).to eq(%w[本格派 技巧派 変則派 パワー型])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/pitcher_styles'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
