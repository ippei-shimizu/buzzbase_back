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
    # メール・パスワードアカウントのいずれも同じ成功レスポンスを返す（届くメールの有無・内容のみ異なる）。
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

      it 'returns the same success response and sends a social login guidance email instead of a reset link' do
        expect do
          post '/api/v1/auth/password', params: {
            email: google_user.email,
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.to change(ActionMailer::Base.deliveries, :count).by(1)

        expect(response).to have_http_status(:ok)
        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq([google_user.email])
        expect(mail.text_part.decoded).to include('Google')
        # body.encoded は multipart + base64 で本文の文字列が現れないため、必ず各パートを decode して見る。
        expect(mail.text_part.decoded).not_to include('password/edit')
        expect(mail.html_part.decoded).not_to include('password/edit')
        expect(google_user.reload.reset_password_token).to be_nil
      end
    end

    context 'with an apple account' do
      let(:apple_user) { create(:user, :apple, email: 'apple-user@example.com', uid: 'apple-uid-123') }

      it 'returns the same success response and sends a social login guidance email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: apple_user.email,
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.to change(ActionMailer::Base.deliveries, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(ActionMailer::Base.deliveries.last.text_part.decoded).to include('Apple')
      end
    end

    context 'with an apple account using a private relay address' do
      let(:apple_user) { create(:user, :apple, email: 'relay-user@privaterelay.appleid.com', uid: 'apple-uid-relay') }

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

    context 'with a soft-deleted google account' do
      let(:google_user) { create(:user, :google, email: 'deleted-google@example.com', uid: 'google-uid-deleted', deleted_at: Time.current) }

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

    context 'with a suspended google account' do
      let(:google_user) do
        create(:user, :google, email: 'suspended-google@example.com', uid: 'google-uid-suspended', suspended_at: Time.current)
      end

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

    context 'with an account of a provider the guidance email does not support' do
      let(:unsupported_user) { create(:user, provider: 'line', email: 'line-user@example.com', uid: 'line-uid-123') }

      it 'returns the same success response without sending an email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: unsupported_user.email,
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a google account and an email in different case' do
      before { create(:user, :google, email: 'case-google@example.com', uid: 'google-uid-case') }

      it 'sends the social login guidance email' do
        expect do
          post '/api/v1/auth/password', params: {
            email: 'Case-Google@Example.com',
            redirect_url: 'http://localhost:8100/reset-password'
          }
        end.to change(ActionMailer::Base.deliveries, :count).by(1)
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

    context 'with a symbol in the new password' do
      it 'returns an error like sign up does' do
        put '/api/v1/auth/password',
            headers:,
            params: { password: 'new-password', password_confirmation: 'new-password' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(user.reload.valid_password?('oldpassword123')).to be true
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

    context 'with a google account that has no password yet' do
      let(:social_user) { create(:user, :google, email: 'set-password@example.com', uid: 'google-uid-set-password') }
      let(:social_headers) { auth_headers_for(social_user) }

      it 'sets the password without the current password, and the account can sign in with it' do
        put '/api/v1/auth/password',
            headers: social_headers,
            params: { password: 'newpassword456', password_confirmation: 'newpassword456' }

        expect(response).to have_http_status(:ok)
        expect(social_user.reload.provider).to eq('google')

        post '/api/v1/auth/sign_in', params: { email: social_user.email, password: 'newpassword456' }
        expect(response).to have_http_status(:ok)
      end

      it 'rejects a password with non-alphanumeric characters' do
        put '/api/v1/auth/password',
            headers: social_headers,
            params: { password: 'new-password', password_confirmation: 'new-password' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(social_user.reload.encrypted_password).to be_blank
      end

      it 'rejects mismatching passwords' do
        put '/api/v1/auth/password',
            headers: social_headers,
            params: { password: 'newpassword456', password_confirmation: 'different456' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(social_user.reload.encrypted_password).to be_blank
      end

      it 'rejects a request without the password confirmation' do
        put '/api/v1/auth/password',
            headers: social_headers,
            params: { password: 'newpassword456' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a google account that already has a password' do
      let(:social_user) do
        create(:user, :google, email: 'change-password@example.com', uid: 'google-uid-change-password',
                               password: 'oldpassword123', password_confirmation: 'oldpassword123')
      end

      it 'changes the password without the current password' do
        put '/api/v1/auth/password',
            headers: auth_headers_for(social_user),
            params: { password: 'newpassword456', password_confirmation: 'newpassword456' }

        expect(response).to have_http_status(:ok)

        post '/api/v1/auth/sign_in', params: { email: social_user.email, password: 'oldpassword123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'clears allow_password_change left over from a reset link opened before linking' do
        social_user.update!(allow_password_change: true)

        put '/api/v1/auth/password',
            headers: auth_headers_for(social_user),
            params: { password: 'newpassword456', password_confirmation: 'newpassword456' }

        expect(response).to have_http_status(:ok)
        expect(social_user.reload.allow_password_change).to be false
      end

      context 'when check_current_password_before_update is enabled' do
        before { allow(DeviseTokenAuth).to receive(:check_current_password_before_update).and_return(:password) }

        it 'rejects a change without the current password' do
          put '/api/v1/auth/password',
              headers: auth_headers_for(social_user),
              params: { password: 'newpassword456', password_confirmation: 'newpassword456' }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'accepts a change with the current password' do
          put '/api/v1/auth/password',
              headers: auth_headers_for(social_user),
              params: { password: 'newpassword456', password_confirmation: 'newpassword456', current_password: 'oldpassword123' }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with a google account that has no password yet when check_current_password_before_update is enabled' do
      let(:social_user) { create(:user, :google, email: 'first-password@example.com', uid: 'google-uid-first-password') }

      before { allow(DeviseTokenAuth).to receive(:check_current_password_before_update).and_return(:password) }

      it 'still sets the first password without the current password' do
        put '/api/v1/auth/password',
            headers: auth_headers_for(social_user),
            params: { password: 'newpassword456', password_confirmation: 'newpassword456' }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
