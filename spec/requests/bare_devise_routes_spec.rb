require 'rails_helper'

# test 環境は show_exceptions = false のため、未定義ルートは 404 ではなく RoutingError として観測する。
RSpec.describe 'Bare Devise routes', type: :request do
  let(:password) { 'password123' }
  let!(:linked_user) do
    create(:user, :google, email: 'linked@example.com', uid: 'google-uid-linked',
                           password:, password_confirmation: password)
  end

  it 'does not route POST /users/sign_in, so a social account with a leftover password cannot sign in through it' do
    expect do
      post '/users/sign_in', params: { user: { email: linked_user.email, password: } }
    end.to raise_error(ActionController::RoutingError)
  end

  it 'does not route POST /users/password' do
    expect do
      post '/users/password', params: { user: { email: linked_user.email } }
    end.to raise_error(ActionController::RoutingError)
  end

  it 'does not route PUT /users/password' do
    expect do
      put '/users/password', params: {
        user: { reset_password_token: 'token', password: 'newpassword456', password_confirmation: 'newpassword456' }
      }
    end.to raise_error(ActionController::RoutingError)
  end

  it 'does not route POST /users' do
    expect do
      post '/users', params: { user: { email: 'bare-signup@example.com', password:, password_confirmation: password } }
    end.to raise_error(ActionController::RoutingError)
  end

  it 'keeps GET /users/confirmation routed to the custom confirmations controller' do
    expect do
      get '/users/confirmation', params: { confirmation_token: 'invalid-token' }
    end.not_to raise_error
  end
end
