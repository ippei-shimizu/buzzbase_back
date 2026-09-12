require 'rails_helper'

RSpec.describe App::Stripe::WebhookProcessor do
  let(:user) { create(:user) }
  let(:fixture) do
    JSON.parse(Rails.root.join('spec/fixtures/stripe/checkout_session_completed.json').read).tap do |data|
      data['data']['object']['metadata']['user_id'] = user.id.to_s
    end
  end
  let(:event) { Stripe::Event.construct_from(fixture) }
  let(:webhook_event) do
    create(:webhook_event,
           provider: 'stripe',
           external_event_id: event.id,
           event_type: event.type,
           payload: event.to_hash)
  end

  describe '#process' do
    subject(:process!) { described_class.new(webhook_event).process }

    context 'webhook_event がまだ pending のとき' do
      it 'status を processed に更新する' do
        expect { process! }.to change { webhook_event.reload.status }.from('pending').to('processed')
      end

      it 'CheckoutSessionCompletedHandler#call が呼ばれ、Subscription に Stripe ID が保存される' do
        process!
        expect(user.reload.subscription.stripe_customer_id).to eq('cus_test_abc123')
      end
    end

    context 'webhook_event が既に processed のとき' do
      let(:webhook_event) do
        create(:webhook_event, :processed,
               provider: 'stripe',
               external_event_id: event.id,
               event_type: event.type,
               payload: event.to_hash)
      end

      it '冪等性のため再処理しない' do
        original_processed_at = webhook_event.processed_at
        process!
        expect(webhook_event.reload.processed_at).to be_within(1.second).of(original_processed_at)
      end
    end

    context 'handler が例外を投げたとき' do
      let(:failing_handler) { instance_double(App::Stripe::Handlers::CheckoutSessionCompletedHandler) }

      before do
        allow(failing_handler).to receive(:call).and_raise(StandardError, 'boom')
        allow(App::Stripe::EventDispatcher).to receive(:handler_for).and_return(failing_handler)
        allow(Sentry).to receive(:capture_exception)
      end

      it 'webhook_event を failed に遷移させ Sentry 通知し再 raise する' do
        expect { process! }.to raise_error(StandardError, 'boom')
        expect(Sentry).to have_received(:capture_exception).with(
          instance_of(StandardError),
          hash_including(tags: hash_including(source: 'stripe_webhook'))
        )
        expect(webhook_event.reload.status).to eq('failed')
        expect(webhook_event.error_message).to include('boom')
      end

      context '更に mark_failed! 自体も例外で落ちるとき' do
        before do
          allow(webhook_event).to receive(:mark_failed!).and_raise(StandardError, 'db down')
        end

        it '元の handler 例外を必ず Sentry に届け、mark_failed! の例外も別タグで通知する' do
          expect { process! }.to raise_error(StandardError, 'boom')

          expect(Sentry).to have_received(:capture_exception).with(
            instance_of(StandardError),
            hash_including(tags: hash_including(source: 'stripe_webhook_mark_failed'))
          )
          expect(Sentry).to have_received(:capture_exception).with(
            having_attributes(message: 'boom'),
            hash_including(tags: hash_including(source: 'stripe_webhook'))
          )
        end
      end
    end

    context '未対応 event_type のとき' do
      let(:other_event) do
        Stripe::Event.construct_from(
          id: 'evt_unhandled',
          type: 'invoice.payment_failed',
          data: { object: {} }
        )
      end
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'stripe',
               external_event_id: other_event.id,
               event_type: other_event.type,
               payload: other_event.to_hash)
      end

      it 'processed 扱いにし、状態は触らない（受信記録のみ）' do
        process!
        expect(webhook_event.reload.status).to eq('processed')
      end
    end
  end
end
