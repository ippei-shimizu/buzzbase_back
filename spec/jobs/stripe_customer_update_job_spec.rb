require 'rails_helper'

RSpec.describe StripeCustomerUpdateJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    context 'subscription に stripe_customer_id が紐付いているとき' do
      before do
        user.subscription.update!(platform: 'web', stripe_customer_id: 'cus_test_abc')
        allow(Stripe::Customer).to receive(:update)
      end

      it 'Stripe::Customer.update を user.email で呼ぶ' do
        described_class.new.perform(user.id)
        expect(Stripe::Customer).to have_received(:update).with('cus_test_abc', email: user.email)
      end
    end

    context 'subscription.stripe_customer_id が nil のとき' do
      it 'Stripe API を呼ばない' do
        allow(Stripe::Customer).to receive(:update)
        described_class.new.perform(user.id)
        expect(Stripe::Customer).not_to have_received(:update)
      end
    end

    context 'user が見つからないとき' do
      it '例外を投げず終わる' do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end

    context 'Stripe API が例外を投げるとき' do
      before do
        user.subscription.update!(platform: 'web', stripe_customer_id: 'cus_test_abc')
        allow(Stripe::Customer).to receive(:update).and_raise(Stripe::APIConnectionError.new('boom'))
        allow(Sentry).to receive(:capture_exception)
      end

      it 'fire-and-forget で例外を握り潰し Sentry に通知する' do
        expect { described_class.new.perform(user.id) }.not_to raise_error
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end
end
