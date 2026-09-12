require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Passwords', type: :request do
  before do
    Rails.application.routes.default_url_options[:host] = 'localhost:3000'
    ActionMailer::Base.default_url_options = { host: 'localhost:3000' }
  end

  describe 'POST /api/v1/auth/password' do
    let(:user) do
      create(:user, email: 'reset@example.com', uid: 'reset@example.com')
    end

    context 'with valid email and redirect_url' do
      it 'returns success' do
        post '/api/v1/auth/password', params: {
          email: user.email,
          redirect_url: 'http://localhost:8100/reset-password'
        }

        expect(response).to have_http_status(:ok)
      end

      it 'sends a password reset email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: user.email,
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.to change(ActionMailer::Base.deliveries, :count).by(1)
      end
    end

    # アカウント列挙・認証方式の推測を防ぐため、存在しないメール/Google・Appleアカウント/
    # メール・パスワードアカウントのいずれも同じ成功レスポンスを返す（メール送信の有無のみ異なる）。
    context 'with non-existent email' do
      it 'returns success without sending an email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: 'notfound@example.com',
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a google account' do
      let(:google_user) { create(:user, :google, email: 'google-user@example.com', uid: 'google-uid-123') }

      it 'returns the same success response without sending an email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: google_user.email,
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with an apple account' do
      let(:apple_user) { create(:user, :apple, email: 'apple-user@example.com', uid: 'apple-uid-123') }

      it 'returns the same success response without sending an email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: apple_user.email,
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without redirect_url' do
      it 'returns success by falling back to the default redirect URL instead of erroring' do
        post '/api/v1/auth/password', params: { email: user.email }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a disallowed redirect_url host' do
      it 'returns success and sends the email with the link pointing to the default redirect URL' do
        post '/api/v1/auth/password', params: {
          email: user.email,
          redirect_url: 'https://evil.example.com/steal-token'
        }

        expect(response).to have_http_status(:ok)
        mail_body = ActionMailer::Base.deliveries.last.body.to_s
        expect(mail_body).not_to include('evil.example.com')
      end
    end
  end

  describe 'GET /api/v1/auth/password/edit' do
    let(:user) do
      create(:user, email: 'edit-reset@example.com', uid: 'edit-reset@example.com')
    end

    context 'with valid reset_password_token and web redirect_url' do
      it 'redirects to the front URL with auth token params' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('FRONTEND_URL', nil).and_return('http://localhost:8100')
        allow(ENV).to receive(:fetch).with('CONFIRM_SUCCESS_URL', nil).and_return('http://localhost:8100')

        raw_token = user.send_reset_password_instructions

        get '/api/v1/auth/password/edit', params: {
          reset_password_token: raw_token,
          redirect_url: 'http://localhost:8100/reset-password'
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with('http://localhost:8100/reset-password')
        expect(response.location).to include('reset_password=true')
      end
    end

    context 'with unauthorized redirect_url host' do
      it 'falls back to the default redirect URL instead of the untrusted host' do
        raw_token = user.send_reset_password_instructions

        get '/api/v1/auth/password/edit', params: {
          reset_password_token: raw_token,
          redirect_url: 'https://evil.example.com/steal-token'
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include('evil.example.com')
      end
    end

    context 'with an invalid reset_password_token' do
      it 'does not redirect to an authenticated URL' do
        # devise_token_auth標準のrender_edit_errorはActionController::RoutingErrorを
        # raiseするだけで明示的にrescueしていないため500になる（gem標準の挙動）。
        # ここでは「認証済みURLへリダイレクトされない」ことを実際のステータスコードで
        # 固定し、将来意図せず200/redirectへ変化した場合に検知できるようにする。
        get '/api/v1/auth/password/edit', params: {
          reset_password_token: 'invalid-token',
          redirect_url: 'http://localhost:8100/reset-password'
        }

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'PUT /api/v1/auth/password' do
    let(:user) do
      create(:user, password: 'oldpassword123', password_confirmation: 'oldpassword123')
    end
    let(:headers) { auth_headers_for(user) }

    context 'with valid auth headers and matching passwords' do
      it 'updates the password and returns success' do
        put '/api/v1/auth/password',
            headers:,
            params: {
              password: 'newpassword456',
              password_confirmation: 'newpassword456'
            }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with mismatching passwords' do
      it 'returns an error' do
        put '/api/v1/auth/password',
            headers:,
            params: {
              password: 'newpassword456',
              password_confirmation: 'different456'
            }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without auth headers' do
      it 'rejects the request as unauthorized' do
        put '/api/v1/auth/password', params: {
          password: 'newpassword456',
          password_confirmation: 'newpassword456'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
