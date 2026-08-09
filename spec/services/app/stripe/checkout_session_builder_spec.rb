require 'rails_helper'

RSpec.describe App::Stripe::CheckoutSessionBuilder do
  let(:user) { create(:user) }
  let(:plan) { 'monthly' }
  let(:success_url) { 'https://buzzbase.jp/pro/success' }
  let(:cancel_url) { 'https://buzzbase.jp/pro/cancel' }
  let(:builder) { described_class.new(user:, plan:, success_url:, cancel_url:) }
  let(:stripe_session) { instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.com/c/pay/xxx') }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('STRIPE_PRICE_ID_MONTHLY').and_return('price_monthly_test_123')
    allow(ENV).to receive(:fetch).with('STRIPE_PRICE_ID_YEARLY').and_return('price_yearly_test_456')
    allow(Stripe::Checkout::Session).to receive(:create).and_return(stripe_session)
  end

  describe '#call' do
    context '通常ケース（has_used_trial=false）' do
      it 'Stripe::Checkout::Session.create を期待値で呼び出す' do
        builder.call
        # checkout.session.completed の data.object は Session 自体のため、
        # CheckoutSessionCompletedHandler が読む metadata.user_id は Session 直下に必要
        # （subscription_data.metadata だけでは Handler から参照できない）。
        expected_metadata = { user_id: user.id.to_s, plan: 'monthly' }

        expect(Stripe::Checkout::Session).to have_received(:create) do |args|
          expect(args).to include(
            mode: 'subscription',
            customer_email: user.email,
            line_items: [{ price: 'price_monthly_test_123', quantity: 1 }],
            metadata: expected_metadata,
            success_url:,
            cancel_url:
          )
          expect(args[:subscription_data]).to include(
            trial_period_days: 7,
            metadata: expected_metadata
          )
        end
      end

      it 'Stripe Session を返す' do
        expect(builder.call).to eq(stripe_session)
      end
    end

    context '早期加入者期間内でも trial_period_days は 7 のまま（早期特典による延長は廃止）' do
      before { travel_to Time.zone.parse('2026-06-01 12:00 JST') }

      it 'trial_period_days: 7 で呼び出す' do
        builder.call
        expect(Stripe::Checkout::Session).to have_received(:create) do |args|
          expect(args[:subscription_data][:trial_period_days]).to eq(7)
        end
      end
    end

    context '再加入（has_used_trial=true）' do
      before do
        user.subscription.update!(has_used_trial: true)
      end

      it 'trial_period_days を渡さない（即時課金）' do
        builder.call
        expect(Stripe::Checkout::Session).to have_received(:create) do |args|
          expect(args[:subscription_data]).not_to have_key(:trial_period_days)
        end
      end
    end

    context 'yearly プラン指定時' do
      let(:plan) { 'yearly' }

      it 'STRIPE_PRICE_ID_YEARLY を line_items に渡す' do
        builder.call
        expect(Stripe::Checkout::Session).to have_received(:create) do |args|
          expect(args[:line_items]).to eq([{ price: 'price_yearly_test_456', quantity: 1 }])
        end
      end
    end

    context '既加入（pro_active）のとき' do
      before do
        user.subscription.update!(
          status: 'active',
          plan_type: 'monthly',
          platform: 'ios',
          expires_at: 30.days.from_now,
          has_used_trial: true
        )
      end

      it 'AlreadySubscribedError を raise する' do
        expect { builder.call }.to raise_error(described_class::AlreadySubscribedError)
      end

      it 'Stripe API を呼ばない' do
        expect { builder.call }.to raise_error(described_class::AlreadySubscribedError)
        expect(Stripe::Checkout::Session).not_to have_received(:create)
      end
    end

    context '不正な plan のとき' do
      let(:plan) { 'lifetime' }

      it 'InvalidPlanError を raise する' do
        expect { builder.call }.to raise_error(described_class::InvalidPlanError)
      end
    end
  end
end
