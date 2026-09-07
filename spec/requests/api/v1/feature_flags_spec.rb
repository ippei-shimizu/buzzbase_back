require 'rails_helper'

RSpec.describe 'Api::V1::FeatureFlags', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/feature_flags' do
    context '未認証のとき' do
      it '401 を返す' do
        get '/api/v1/feature_flags', params: { keys: ['pro_features'] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '認証済み + keys 未指定のとき' do
      it '200 + 空オブジェクトを返す' do
        get '/api/v1/feature_flags', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
      end
    end

    context 'pro_features を要求したとき' do
      it '常に true を返す（kill switch 廃止・恒久有効）' do
        get '/api/v1/feature_flags',
            params: { keys: ['pro_features'] },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('pro_features' => true)
      end
    end

    context '未知 key・削除済み key を含めて要求したとき' do
      it '公開 flag 以外はレスポンスに含めない' do
        get '/api/v1/feature_flags',
            params: { keys: %w[pro_features cancellation_survey unknown_flag] },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('pro_features' => true)
      end
    end

    context 'keys に配列以外を渡したとき' do
      it 'ハッシュを渡しても 500 にならず空オブジェクトを返す' do
        get '/api/v1/feature_flags',
            params: { keys: { pro_features: 'true' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
      end

      it 'スカラー値を渡しても 500 にならず空オブジェクトを返す' do
        get '/api/v1/feature_flags',
            params: { keys: 'pro_features' },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
      end
    end

    context '同一 key を重複して指定したとき' do
      it '重複は 1 件に集約されて返る' do
        get '/api/v1/feature_flags',
            params: { keys: %w[pro_features pro_features] },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('pro_features' => true)
      end
    end
  end
end
