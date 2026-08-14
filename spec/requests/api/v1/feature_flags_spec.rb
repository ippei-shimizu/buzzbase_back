require 'rails_helper'

RSpec.describe 'Api::V1::FeatureFlags', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  after do
    Api::V1::FeatureFlagsController::PUBLIC_KEYS.each { |key| Flipper.disable(key.to_sym) }
  end

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

    context '認証済み + keys が空配列のとき' do
      it '200 + 空オブジェクトを返す' do
        get '/api/v1/feature_flags', params: { keys: [] }, headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
      end
    end

    context 'Flipper が全体 disabled のとき' do
      it 'すべての flag が false で返る' do
        get '/api/v1/feature_flags',
            params: { keys: %w[pro_features cancellation_survey] },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          'pro_features' => false,
          'cancellation_survey' => false
        )
      end
    end

    context 'actor 単位で enable されているとき' do
      before { Flipper.enable_actor(:pro_features, user) }

      it '対象 user は true を取得する' do
        get '/api/v1/feature_flags',
            params: { keys: ['pro_features'] },
            headers: auth_headers_for(user)

        expect(response.parsed_body).to eq('pro_features' => true)
      end

      it '他ユーザーは false を取得する' do
        get '/api/v1/feature_flags',
            params: { keys: ['pro_features'] },
            headers: auth_headers_for(other_user)

        expect(response.parsed_body).to eq('pro_features' => false)
      end
    end

    context 'boolean で全体 enable されているとき' do
      before { Flipper.enable(:pro_features) }

      it '誰でも true を取得する' do
        get '/api/v1/feature_flags',
            params: { keys: ['pro_features'] },
            headers: auth_headers_for(other_user)

        expect(response.parsed_body).to eq('pro_features' => true)
      end
    end

    context '両キー指定 + 片方のみ actor enable' do
      before { Flipper.enable_actor(:pro_features, user) }

      it '対応するキーのみ true で返る' do
        get '/api/v1/feature_flags',
            params: { keys: %w[pro_features cancellation_survey] },
            headers: auth_headers_for(user)

        expect(response.parsed_body).to eq(
          'pro_features' => true,
          'cancellation_survey' => false
        )
      end
    end

    context '未知 key を含めて要求したとき' do
      it '未知 key はレスポンスに含めない' do
        get '/api/v1/feature_flags',
            params: { keys: %w[pro_features unknown_flag pro_test_mode] },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('pro_features' => false)
      end
    end

    context '同一 key を重複して指定したとき' do
      it '重複は 1 件に集約されて返る' do
        get '/api/v1/feature_flags',
            params: { keys: %w[pro_features pro_features] },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('pro_features' => false)
      end
    end
  end
end
