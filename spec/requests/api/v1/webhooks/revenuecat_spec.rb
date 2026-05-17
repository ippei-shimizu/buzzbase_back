require 'rails_helper'

RSpec.describe 'Api::V1::Webhooks::Revenuecat', type: :request do
  # 本 Issue ではスタブ実装で 200 を返すだけ。
  # 署名検証 (X-RevenueCat-Signature の HMAC 照合) と payload 解釈・状態遷移は #318 で実装する。
  # スタブ段階でも RevenueCat 側のリトライを抑止するため、どんな入力でも 200 を返すことを保証する。
  describe 'POST /api/v1/webhooks/revenuecat' do
    it 'returns 200 for a normal RevenueCat-shaped JSON payload' do
      post '/api/v1/webhooks/revenuecat',
           params: { event: { type: 'INITIAL_PURCHASE', app_user_id: 'user_1' } },
           as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 for an empty JSON body' do
      post '/api/v1/webhooks/revenuecat', params: {}, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 even without Content-Type header' do
      post '/api/v1/webhooks/revenuecat'
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 for a raw text body that is not valid JSON' do
      # RevenueCat の Retry / Probe 等で payload が想定外でも 4xx を返してはならない。
      # #318 実装時はここを「署名 NG なら 401、payload 不正なら 422」に切り替える設計を検討する。
      post '/api/v1/webhooks/revenuecat',
           params: 'not-a-json',
           headers: { 'CONTENT_TYPE' => 'text/plain' }
      expect(response).to have_http_status(:ok)
    end
  end
end
