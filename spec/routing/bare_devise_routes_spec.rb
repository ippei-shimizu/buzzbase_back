require 'rails_helper'

RSpec.describe 'Bare Devise routes', type: :routing do
  it 'does not route the bare Devise sessions routes' do
    expect(get: '/users/sign_in').not_to be_routable
    expect(post: '/users/sign_in').not_to be_routable
    expect(delete: '/users/sign_out').not_to be_routable
  end

  it 'does not route the bare Devise passwords routes' do
    expect(get: '/users/password/new').not_to be_routable
    expect(post: '/users/password').not_to be_routable
    expect(get: '/users/password/edit').not_to be_routable
    expect(put: '/users/password').not_to be_routable
  end

  it 'does not route the bare Devise registrations routes' do
    expect(get: '/users/sign_up').not_to be_routable
    expect(post: '/users').not_to be_routable
    expect(put: '/users').not_to be_routable
    expect(delete: '/users').not_to be_routable
  end

  it 'keeps GET /users/confirmation routed to the custom confirmations controller' do
    expect(get: '/users/confirmation').to route_to(controller: 'custom_confirmations', action: 'show')
  end
end
