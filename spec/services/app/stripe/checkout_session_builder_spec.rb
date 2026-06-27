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
    allow(ENV).to receive(:fetch).with('EARLY_SUBSCRIBER_WINDOW_START', any_args).and_call_original
    allow(ENV).to receive(:fetch).with('EARLY_SUBSCRIBER_WINDOW_END', any_args).and_call_original
    allow(Stripe::Checkout::Session).to receive(:create).and_return(stripe_session)
  end

  describe '#call' do
    context '通常ケース（has_used_trial=false、早期特典期間外）' do
      before { travel_to_outside_early_window }

      it 'Stripe::Checkout::Session.create を期待値で呼び出す' do
        builder.call
        expect(Stripe::Checkout::Session).to have_received(:create) do |args|
          expect(args[:mode]).to eq('subscription')
          expect(args[:customer_email]).to eq(user.email)
          expect(args[:line_items]).to eq([{ price: 'price_monthly_test_123', quantity: 1 }])
          expect(args[:subscription_data][:trial_period_days]).to eq(7)
          expect(args[:subscription_data][:metadata]).to eq(user_id: user.id.to_s, plan: 'monthly')
          expect(args[:success_url]).to eq(success_url)
          expect(args[:cancel_url]).to eq(cancel_url)
        end
      end

      it 'Stripe Session を返す' do
        expect(builder.call).to eq(stripe_session)
      end
    end

    context '早期特典期間内' do
      before { travel_to_inside_early_window }

      it 'trial_period_days: 30 で呼び出す' do
        builder.call
        expect(Stripe::Checkout::Session).to have_received(:create) do |args|
          expect(args[:subscription_data][:trial_period_days]).to eq(30)
        end
      end
    end

    context '再加入（has_used_trial=true）' do
      before do
        user.subscription.update!(has_used_trial: true)
        travel_to_inside_early_window
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

  def travel_to_inside_early_window
    travel_to Time.zone.parse('2026-06-01 12:00 JST')
  end

  def travel_to_outside_early_window
    travel_to Time.zone.parse('2026-08-01 12:00 JST')
  end
end
