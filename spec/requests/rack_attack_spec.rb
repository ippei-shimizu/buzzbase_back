require 'rails_helper'

RSpec.describe 'Rack::Attack throttling', type: :request do
  # Rack::Attack は test 環境では既定で無効なので、このスペック内でのみ有効化する。
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  let(:json_headers) { { 'CONTENT_TYPE' => 'application/json' } }

  def post_sign_in(email:, ip:)
    post '/api/v1/auth/sign_in',
         params: { email:, password: 'wrong_password' }.to_json,
         headers: json_headers.merge('X-Forwarded-For' => ip)
  end

  describe 'POST /api/v1/auth/sign_in' do
    context 'when the same IP exceeds the limit' do
      it 'returns 429 with a stable error code' do
        10.times { |i| post_sign_in(email: "attacker#{i}@example.com", ip: '203.0.113.10') }
        expect(response).to have_http_status(:unauthorized)

        post_sign_in(email: 'attacker10@example.com', ip: '203.0.113.10')

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body['error']).to eq('rate_limit_exceeded')
        expect(response.parsed_body['message']).to be_present
        expect(response.headers['Retry-After'].to_i).to be_positive
      end
    end

    context 'when the same email is attacked from many IPs' do
      # JSON ボディの email を Rack::Attack が読めることの回帰テスト。
      it 'returns 429' do
        5.times { |i| post_sign_in(email: 'victim@example.com', ip: "198.51.100.#{i}") }
        expect(response).to have_http_status(:unauthorized)

        post_sign_in(email: 'victim@example.com', ip: '198.51.100.99')

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body['error']).to eq('rate_limit_exceeded')
      end
    end

    context 'when the email is sent as form-encoded params' do
      it 'returns 429' do
        5.times do |i|
          post '/api/v1/auth/sign_in',
               params: { email: 'formvictim@example.com', password: 'wrong_password' },
               headers: { 'X-Forwarded-For' => "192.0.2.#{i}" }
        end

        post '/api/v1/auth/sign_in',
             params: { email: 'formvictim@example.com', password: 'wrong_password' },
             headers: { 'X-Forwarded-For' => '192.0.2.99' }

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context 'when within the limit' do
      let(:user) do
        create(:user, email: 'within@example.com', uid: 'within@example.com', password: 'password123',
                      password_confirmation: 'password123')
      end

      it 'lets the request through' do
        3.times { |i| post_sign_in(email: "someone#{i}@example.com", ip: '203.0.113.20') }

        post '/api/v1/auth/sign_in',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: json_headers.merge('X-Forwarded-For' => '203.0.113.20')

        expect(response).to have_http_status(:ok)
        expect(response.headers['access-token']).to be_present
      end
    end
  end

  describe 'POST /api/v1/auth/password' do
    it 'throttles repeated reset requests for the same email' do
      3.times do |i|
        post '/api/v1/auth/password',
             params: { email: 'reset-target@example.com', redirect_url: 'http://localhost:8100/reset-password' }.to_json,
             headers: json_headers.merge('X-Forwarded-For' => "203.0.113.#{100 + i}")
      end

      post '/api/v1/auth/password',
           params: { email: 'reset-target@example.com', redirect_url: 'http://localhost:8100/reset-password' }.to_json,
           headers: json_headers.merge('X-Forwarded-For' => '203.0.113.199')

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'POST /api/v1/admin/sign_in' do
    it 'throttles repeated attempts from the same IP' do
      5.times do
        post '/api/v1/admin/sign_in',
             params: { email: 'admin@example.com', password: 'wrong_password' }.to_json,
             headers: json_headers.merge('X-Forwarded-For' => '203.0.113.30')
      end

      post '/api/v1/admin/sign_in',
           params: { email: 'admin@example.com', password: 'wrong_password' }.to_json,
           headers: json_headers.merge('X-Forwarded-For' => '203.0.113.30')

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'endpoints outside the throttle list' do
    it 'does not throttle token validation' do
      30.times do
        get '/api/v1/auth/validate_token', headers: { 'X-Forwarded-For' => '203.0.113.40' }
      end

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
