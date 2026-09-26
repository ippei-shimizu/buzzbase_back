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

    context 'with valid confirmation token' do
      it 'includes auth tokens in the redirect URL so the client can skip manual sign in' do
        get '/api/v1/auth/confirmation', params: {
          confirmation_token: user.confirmation_token,
          redirect_url: 'buzzbase://confirmation-success'
        }

        query = Rack::Utils.parse_query(URI.parse(response.location).query)
        expect(query['access-token']).to be_present
        expect(query['client']).to be_present
        expect(query['uid']).to eq(user.uid)
      end

      it 'issues auth tokens that authenticate the user' do
        get '/api/v1/auth/confirmation', params: {
          confirmation_token: user.confirmation_token,
          redirect_url: 'buzzbase://confirmation-success'
        }

        query = Rack::Utils.parse_query(URI.parse(response.location).query)
        get '/api/v1/auth/validate_token', headers: {
          'access-token' => query['access-token'],
          'client' => query['client'],
          'uid' => query['uid']
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when it falls back to the relative default redirect URL' do
      it 'keeps the path intact and still carries the auth tokens' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('CONFIRM_SUCCESS_URL').and_return(nil)
        allow(ENV).to receive(:fetch).with('CONFIRM_SUCCESS_URL', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('FRONTEND_URL', nil).and_return(nil)

        get '/api/v1/auth/confirmation', params: { confirmation_token: user.confirmation_token }

        location = URI.parse(response.location)
        expect(location.path).to eq('/signin')
        query = Rack::Utils.parse_query(location.query)
        expect(query['access-token']).to be_present
        expect(query['uid']).to eq(user.uid)
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

      it 'does not include auth tokens in the redirect URL' do
        get '/api/v1/auth/confirmation', params: {
          confirmation_token: 'invalid_token',
          redirect_url: 'buzzbase://confirmation-success'
        }

        query = Rack::Utils.parse_query(URI.parse(response.location).query)
        expect(query['access-token']).to be_nil
        expect(query['uid']).to be_nil
      end
    end
  end
end
