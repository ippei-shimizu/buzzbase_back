require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Apple', type: :request do
  let(:apple_uid) { '001234.abcdef1234567890.1234' }
  let(:email) { 'apple-user@privaterelay.appleid.com' }
  let(:apple_data) { { uid: apple_uid, email:, name: '山田 太郎' } }

  before do
    allow(AppleAuthService).to receive(:verify).and_return(apple_data)
  end

  describe 'POST /api/v1/apple_sign_in' do
    context '新規ユーザーの場合' do
      it 'ユーザーを作成してログインする' do
        expect do
          post '/api/v1/apple_sign_in', params: { identity_token: 'valid_token' }
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.headers['access-token']).to be_present
        expect(response.headers['client']).to be_present
        expect(response.headers['uid']).to be_present

        json = JSON.parse(response.body)
        expect(json['requires_username']).to be true
      end

      it 'provider: apple で作成される' do
        post '/api/v1/apple_sign_in', params: { identity_token: 'valid_token' }

        user = User.last
        expect(user.provider).to eq('apple')
        expect(user.uid).to eq(apple_uid)
        expect(user.email).to eq(email)
        expect(user.confirmed_at).to be_present
      end
    end

    context '既存のAppleユーザーの場合' do
      let!(:existing_user) do
        create(:user, provider: 'apple', uid: apple_uid, email:, user_id: 'yamada')
      end

      it '既存ユーザーでログインする' do
        expect do
          post '/api/v1/apple_sign_in', params: { identity_token: 'valid_token' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['requires_username']).to be false
      end
    end

    context 'メールアドレスが既存のユーザーと一致する場合' do
      let!(:existing_user) do
        create(:user, provider: 'email', uid: email, email:, user_id: 'yamada')
      end

      it 'providerをappleに更新してリンクする' do
        expect do
          post '/api/v1/apple_sign_in', params: { identity_token: 'valid_token' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)

        existing_user.reload
        expect(existing_user.provider).to eq('apple')
        expect(existing_user.uid).to eq(apple_uid)
      end
    end

    context 'identity_tokenが未指定の場合' do
      it '401を返す' do
        post '/api/v1/apple_sign_in', params: {}

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'トークンが無効な場合' do
      before do
        allow(AppleAuthService).to receive(:verify).and_raise(
          AppleAuthService::InvalidToken, 'Apple IDトークンの検証に失敗しました'
        )
      end

      it '401を返す' do
        post '/api/v1/apple_sign_in', params: { identity_token: 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Apple IDトークンの検証に失敗しました')
      end
    end

    context 'アカウントが停止されている場合' do
      let!(:suspended_user) do
        create(:user, provider: 'apple', uid: apple_uid, email:, suspended_at: Time.current)
      end

      it '401を返す' do
        post '/api/v1/apple_sign_in', params: { identity_token: 'valid_token' }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('アカウントが停止されています')
      end
    end

    context 'アカウントが削除されている場合' do
      let!(:deleted_user) do
        create(:user, provider: 'apple', uid: apple_uid, email:, deleted_at: Time.current)
      end

      it '401を返す' do
        post '/api/v1/apple_sign_in', params: { identity_token: 'valid_token' }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('アカウントが削除されています')
      end
    end

    context 'full_nameが送信された場合' do
      let(:apple_data) { { uid: apple_uid, email:, name: '山田 太郎' } }

      it 'nameが保存される' do
        post '/api/v1/apple_sign_in', params: {
          identity_token: 'valid_token',
          full_name: { given_name: '太郎', family_name: '山田' }
        }

        expect(response).to have_http_status(:ok)
        user = User.last
        expect(user.name).to eq('山田 太郎')
      end
    end
  end
end
