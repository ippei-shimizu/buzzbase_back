require 'rails_helper'

RSpec.describe 'CustomConfirmationsController', type: :request do
  before do
    Rails.application.routes.default_url_options[:host] = 'localhost:3000'
    ActionMailer::Base.default_url_options = { host: 'localhost:3000' }
  end

  describe 'GET /api/v1/auth/confirmation' do
    let(:user) do
      create(:user, :unconfirmed, email: 'test@example.com', uid: 'test@example.com')
    end

    context 'with valid confirmation token and web redirect_url' do
      it 'confirms the user and redirects to the web URL' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('FRONTEND_URL', nil).and_return('http://localhost:8100')
        allow(ENV).to receive(:fetch).with('CONFIRM_SUCCESS_URL', nil).and_return('http://localhost:8100')

        get '/api/v1/auth/confirmation', params: {
          confirmation_token: user.confirmation_token,
          redirect_url: 'http://localhost:8100/signin'
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('http://localhost:8100/signin')
        expect(response.location).to include('account_confirmation_success=true')
      end
    end

    context 'with valid confirmation token and mobile app scheme redirect_url' do
      it 'confirms the user and redirects to the mobile app' do
        get '/api/v1/auth/confirmation', params: {
          confirmation_token: user.confirmation_token,
          redirect_url: 'buzzbase://confirmation-success'
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('buzzbase://confirmation-success')
        expect(response.location).to include('account_confirmation_success=true')
      end
    end

    context 'with unauthorized redirect_url scheme' do
      it 'falls back to the default redirect URL' do
        get '/api/v1/auth/confirmation', params: {
          confirmation_token: user.confirmation_token,
          redirect_url: 'evilapp://hack'
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include('evilapp://')
      end
    end

    context 'with invalid confirmation token' do
      it 'redirects with error parameters' do
        get '/api/v1/auth/confirmation', params: {
          confirmation_token: 'invalid_token',
          redirect_url: 'buzzbase://confirmation-success'
        }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('account_confirmation_success=false')
      end
    end
  end
end
