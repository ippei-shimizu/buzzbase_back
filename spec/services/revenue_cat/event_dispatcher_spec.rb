require 'rails_helper'

RSpec.describe RevenueCat::EventDispatcher do
  describe '.handler_for' do
    def payload_for(event_type)
      RevenueCat::WebhookPayload.new('event' => { 'id' => 'evt_x', 'type' => event_type })
    end

    {
      'INITIAL_PURCHASE' => RevenueCat::Handlers::InitialPurchaseHandler,
      'TRIAL_STARTED' => RevenueCat::Handlers::InitialPurchaseHandler,
      'RENEWAL' => RevenueCat::Handlers::RenewalHandler,
      'CANCELLATION' => RevenueCat::Handlers::CancellationHandler,
      'EXPIRATION' => RevenueCat::Handlers::ExpirationHandler,
      'BILLING_ISSUE' => RevenueCat::Handlers::BillingIssueHandler,
      'REFUND' => RevenueCat::Handlers::RefundHandler,
      'UNCANCELLATION' => RevenueCat::Handlers::UncancellationHandler,
      'PRODUCT_CHANGE' => RevenueCat::Handlers::ProductChangeHandler
    }.each do |event_type, expected_handler|
      it "#{event_type} を #{expected_handler.name.split('::').last} に dispatch する" do
        handler = described_class.handler_for(payload_for(event_type))
        expect(handler).to be_an_instance_of(expected_handler)
      end
    end

    it '未知の event_type は UnknownEventHandler に fallback する' do
      handler = described_class.handler_for(payload_for('TOTALLY_UNKNOWN'))
      expect(handler).to be_an_instance_of(RevenueCat::Handlers::UnknownEventHandler)
    end
  end
end
