require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Registrations', type: :request do
  before do
    Rails.application.routes.default_url_options[:host] = 'localhost:3000'
    ActionMailer::Base.default_url_options = { host: 'localhost:3000' }
  end

  describe 'POST /api/v1/auth' do
    let(:valid_params) do
      {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        name: 'テストユーザー',
        confirm_success_url: 'http://localhost:8100'
      }
    end

    context 'when password is missing' do
      it 'returns an error' do
        post '/api/v1/auth', params: valid_params.except(:password)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when email is already taken' do
      before do
        create(:user, email: 'newuser@example.com', uid: 'newuser@example.com')
      end

      it 'returns an error about duplicate email' do
        post '/api/v1/auth', params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['errors']).to be_present
      end
    end

    context 'when email sending fails' do
      before do
        mail_double = instance_double(ActionMailer::MessageDelivery)
        allow(mail_double).to receive(:deliver_now).and_raise(StandardError.new('SMTP error'))
        allow(EmailAuthenticationMailer).to receive(:send_when_signup).and_return(mail_double)
      end

      it 'still returns success (user is created)' do
        post '/api/v1/auth', params: valid_params

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['status']).to eq('success')
      end
    end

    context 'with valid params' do
      it 'creates a user and returns success' do
        expect do
          post '/api/v1/auth', params: valid_params
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['status']).to eq('success')
      end

      it 'passes confirm_success_url to the mailer' do
        mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
        allow(EmailAuthenticationMailer).to receive(:send_when_signup).and_return(mail_double)

        post '/api/v1/auth', params: valid_params

        expect(EmailAuthenticationMailer).to have_received(:send_when_signup)
          .with(an_instance_of(User), 'http://localhost:8100')
      end

      it 'passes mobile app scheme url to the mailer when confirm_success_url is buzzbase://' do
        mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
        allow(EmailAuthenticationMailer).to receive(:send_when_signup).and_return(mail_double)

        post '/api/v1/auth', params: valid_params.merge(confirm_success_url: 'buzzbase://confirmation-success')

        expect(EmailAuthenticationMailer).to have_received(:send_when_signup)
          .with(an_instance_of(User), 'buzzbase://confirmation-success')
      end
    end
  end
end
