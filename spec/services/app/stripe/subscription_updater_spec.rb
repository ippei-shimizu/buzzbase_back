require 'rails_helper'

RSpec.describe App::Stripe::SubscriptionUpdater do
  let(:user) { create(:user) }
  let(:updater) { described_class.new(user) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('STRIPE_PRICE_ID_MONTHLY').and_return('price_monthly')
    allow(ENV).to receive(:fetch).with('STRIPE_PRICE_ID_YEARLY').and_return('price_yearly')
  end

  describe '#cancel_at_period_end' do
    context 'stripe_subscription_id が紐付いていないとき' do
      it 'NoStripeSubscriptionError を raise する' do
        expect { updater.cancel_at_period_end }.to raise_error(described_class::NoStripeSubscriptionError)
      end
    end

    context 'stripe_subscription_id が紐付いているとき' do
      before do
        user.subscription.update!(stripe_subscription_id: 'sub_test_abc123')
        allow(Stripe::Subscription).to receive(:update)
      end

      it 'Stripe::Subscription.update で cancel_at_period_end: true を呼び出す' do
        updater.cancel_at_period_end
        expect(Stripe::Subscription).to have_received(:update).with('sub_test_abc123', cancel_at_period_end: true)
      end
    end
  end

  describe '#change_plan' do
    let(:stripe_subscription_item) { instance_double(Stripe::SubscriptionItem, id: 'si_test_abc') }
    let(:stripe_subscription) { instance_double(Stripe::Subscription, items: double(data: [stripe_subscription_item])) }

    context 'stripe_subscription_id が紐付いていないとき' do
      it 'NoStripeSubscriptionError を raise する' do
        expect { updater.change_plan('yearly') }.to raise_error(described_class::NoStripeSubscriptionError)
      end
    end

    context '不正な plan のとき' do
      before { user.subscription.update!(stripe_subscription_id: 'sub_test_abc123') }

      it 'InvalidPlanError を raise する' do
        expect { updater.change_plan('lifetime') }.to raise_error(described_class::InvalidPlanError)
      end
    end

    context '正常時' do
      before do
        user.subscription.update!(stripe_subscription_id: 'sub_test_abc123')
        allow(Stripe::Subscription).to receive(:retrieve).with('sub_test_abc123').and_return(stripe_subscription)
        allow(Stripe::Subscription).to receive(:update)
      end

      it 'プラン変更 API を期待値で呼ぶ（proration 有効）' do
        updater.change_plan('yearly')
        expect(Stripe::Subscription).to have_received(:update).with(
          'sub_test_abc123',
          items: [{ id: 'si_test_abc', price: 'price_yearly' }],
          proration_behavior: 'create_prorations'
        )
      end
    end
  end
end
