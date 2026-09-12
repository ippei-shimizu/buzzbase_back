require 'rails_helper'

RSpec.describe App::Stripe::EventDispatcher do
  def payload_for(event_type)
    App::Stripe::WebhookPayload.new(
      Stripe::Event.construct_from(id: 'evt_x', type: event_type, data: { object: {} })
    )
  end

  describe '.handler_for' do
    it 'checkout.session.completed を CheckoutSessionCompletedHandler に dispatch する' do
      handler = described_class.handler_for(payload_for('checkout.session.completed'))
      expect(handler).to be_an_instance_of(App::Stripe::Handlers::CheckoutSessionCompletedHandler)
    end

    it '未対応の event_type は UnhandledEventHandler に fallback する' do
      handler = described_class.handler_for(payload_for('invoice.payment_failed'))
      expect(handler).to be_an_instance_of(App::Stripe::Handlers::UnhandledEventHandler)
    end
  end
end
