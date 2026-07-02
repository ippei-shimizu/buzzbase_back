require 'rails_helper'

RSpec.describe 'Api::V2::Stats batting_trend (season)', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/stats/batting_trend?granularity=season' do
    context '無料ユーザー' do
      it 'シーズン粒度は403（Pro限定）' do
        get '/api/v2/stats/batting_trend', params: { granularity: 'season' }, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end

      it '月粒度（既存）は無料でも200' do
        get '/api/v2/stats/batting_trend', params: { granularity: 'month' }, headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'Pro ユーザー' do
      before { make_pro(user) }

      it 'シーズン単位の推移を返す' do
        season = create(:season, user:, name: '2026春')
        game = create(:game_result, user:, season:)
        create(:batting_average, game_result: game, user:, at_bats: 4, hit: 2, total_bases: 2)

        get '/api/v2/stats/batting_trend', params: { granularity: 'season' }, headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['granularity']).to eq('season')
        expect(body['points'].first['label']).to eq('2026春')
      end
    end
  end
end
