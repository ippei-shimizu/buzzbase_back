require 'rails_helper'

RSpec.describe App::Stripe::Handlers::CheckoutSessionCompletedHandler do
  let(:user) { create(:user) }
  let(:fixture) do
    JSON.parse(Rails.root.join('spec/fixtures/stripe/checkout_session_completed.json').read).tap do |data|
      data['data']['object']['metadata']['user_id'] = user.id.to_s
    end
  end
  let(:event) { Stripe::Event.construct_from(fixture) }
  let(:payload) { App::Stripe::WebhookPayload.new(event) }
  let(:handler) { described_class.new(payload) }

  describe '#call' do
    context '正常系（metadata.user_id から User を解決できる）' do
      it 'Subscription に stripe_customer_id / stripe_subscription_id を保存する' do
        handler.call
        subscription = user.reload.subscription
        expect(subscription.stripe_customer_id).to eq('cus_test_abc123')
        expect(subscription.stripe_subscription_id).to eq('sub_test_abc123')
      end

      it 'status / plan_type 等は触らない（RevenueCat 経由で更新される）' do
        original_status = user.subscription.status
        handler.call
        expect(user.reload.subscription.status).to eq(original_status)
      end
    end

    context 'metadata に user_id が無いとき' do
      before { fixture['data']['object']['metadata'] = {} }

      it 'Sentry warning を残し MissingMetadataError を投げる（processed扱いで埋もれさせない）' do
        allow(Sentry).to receive(:capture_message)

        expect { handler.call }.to raise_error(described_class::MissingMetadataError)

        expect(Sentry).to have_received(:capture_message).with(
          a_string_including('user_id'),
          hash_including(level: :warning)
        )
      end
    end

    context '未知の user_id のとき' do
      before { fixture['data']['object']['metadata']['user_id'] = '99999999' }

      it 'Sentry warning を残し UnresolvedUserError を投げる（Subscription は更新しない）' do
        allow(Sentry).to receive(:capture_message)

        expect { handler.call }.to raise_error(described_class::UnresolvedUserError)

        expect(Sentry).to have_received(:capture_message).with(
          a_string_including('user not found'),
          hash_including(level: :warning)
        )
      end
    end
  end
end
