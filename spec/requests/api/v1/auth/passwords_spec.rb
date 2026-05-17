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

    context 'with non-existent email' do
      it 'returns not found' do
        post '/api/v1/auth/password', params: {
          email: 'notfound@example.com',
          redirect_url: 'http://localhost:8100/reset-password'
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without redirect_url' do
      it 'returns an error' do
        post '/api/v1/auth/password', params: { email: user.email }

        expect(response).to have_http_status(:unauthorized).or have_http_status(:unprocessable_entity)
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
