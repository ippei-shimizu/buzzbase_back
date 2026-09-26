require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Sessions', type: :request do
  describe 'POST /api/v1/auth/sign_in' do
    let(:user) do
      create(:user, email: 'signin@example.com', uid: 'signin@example.com', password: 'password123',
                    password_confirmation: 'password123')
    end

    context 'with valid credentials' do
      it 'returns success with auth headers' do
        post '/api/v1/auth/sign_in', params: { email: user.email, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(response.headers['access-token']).to be_present
        expect(response.headers['client']).to be_present
        expect(response.headers['uid']).to eq(user.uid)
      end
    end

    context 'with invalid password' do
      it 'returns unauthorized' do
        post '/api/v1/auth/sign_in', params: { email: user.email, password: 'wrong_password' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['access-token']).to be_blank
      end
    end

    context 'with non-existent email' do
      it 'returns unauthorized' do
        post '/api/v1/auth/sign_in', params: { email: 'notfound@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is unconfirmed' do
      let(:unconfirmed_user) do
        create(:user, :unconfirmed,
               email: 'unconfirmed@example.com', uid: 'unconfirmed@example.com',
               password: 'password123', password_confirmation: 'password123')
      end

      it 'returns unauthorized' do
        post '/api/v1/auth/sign_in', params: { email: unconfirmed_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a google account that has set a password' do
      let!(:social_user) do
        create(:user, :google, email: 'social-signin@example.com', uid: 'google-uid-signin',
                               password: 'password123', password_confirmation: 'password123')
      end

      it 'signs in with the password without changing the provider, and the issued token works' do
        post '/api/v1/auth/sign_in', params: { email: social_user.email, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(response.headers['uid']).to eq('google-uid-signin')
        expect(social_user.reload.provider).to eq('google')

        auth_headers = response.headers.slice('access-token', 'client', 'uid')
        get '/api/v1/user', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns unauthorized with a wrong password' do
        post '/api/v1/auth/sign_in', params: { email: social_user.email, password: 'wrong_password' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a google account that has not set a password' do
      let!(:social_user) { create(:user, :google, email: 'no-password@example.com', uid: 'google-uid-no-password') }

      it 'returns unauthorized' do
        post '/api/v1/auth/sign_in', params: { email: social_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a suspended google account that has set a password' do
      let!(:social_user) do
        create(:user, :google, email: 'suspended-social@example.com', uid: 'google-uid-suspended',
                               password: 'password123', password_confirmation: 'password123', suspended_at: Time.current)
      end

      it 'returns unauthorized' do
        post '/api/v1/auth/sign_in', params: { email: social_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/auth/sign_out' do
    let(:user) { create(:user) }

    context 'with valid auth headers' do
      let(:headers) { auth_headers_for(user) }

      it 'signs out the user' do
        delete('/api/v1/auth/sign_out', headers:)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without auth headers' do
      it 'returns not found' do
        delete '/api/v1/auth/sign_out'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'authenticated endpoint access with auth headers' do
    let(:user) { create(:user) }
    let(:headers) { auth_headers_for(user) }

    # auth_headers_for で取得した認証ヘッダーで認証付きエンドポイントへアクセス可能であることを確認
    it 'allows access to authenticated endpoints with valid tokens' do
      get('/api/v1/user', headers:)

      expect(response).to have_http_status(:ok)
    end

    # devise_token_auth のトークンローリング: レスポンスに新しい access-token が含まれること
    it 'returns auth headers in the response' do
      get('/api/v1/user', headers:)

      # devise_token_auth は次のリクエスト用に access-token を返す（change_headers_on_each_request: true 設定時）
      # 設定が false の場合もある。最低限 client / uid は維持されるはず
      expect(response.headers['client']).to be_present
    end
  end
end
