require 'rails_helper'

RSpec.describe RevenueCatWebhookProcessor do
  let(:event_id) { 'evt_initial_purchase_001' }
  let(:payload) do
    {
      'event' => {
        'id' => event_id,
        'type' => 'INITIAL_PURCHASE',
        'app_user_id' => 'user_1'
      }
    }
  end
  let(:webhook_event) do
    create(:webhook_event,
           provider: 'revenuecat',
           external_event_id: event_id,
           event_type: 'INITIAL_PURCHASE',
           payload:)
  end

  describe '#process' do
    subject(:process!) { described_class.new(webhook_event).process }

    context 'webhook_event がまだ pending のとき' do
      it 'status を processed に更新する' do
        expect { process! }.to change { webhook_event.reload.status }.from('pending').to('processed')
      end

      it 'processed_at をセットする' do
        process!
        expect(webhook_event.reload.processed_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'webhook_event が既に processed のとき' do
      let(:webhook_event) { create(:webhook_event, :processed, provider: 'revenuecat', external_event_id: event_id) }

      it '冪等性のため処理を実行しない（status を変えない）' do
        original_processed_at = webhook_event.processed_at
        process!
        expect(webhook_event.reload.processed_at).to be_within(1.second).of(original_processed_at)
      end
    end

    context 'handler 実装中に例外が発生したとき' do
      let(:processor) { described_class.new(webhook_event) }

      before do
        allow(processor).to receive(:handle_event).and_raise(StandardError, 'boom')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'webhook_event を failed 状態に遷移させて Sentry に通知し、例外を再 raise する' do
        expect { processor.process }.to raise_error(StandardError, 'boom')

        expect(Sentry).to have_received(:capture_exception).with(
          instance_of(StandardError),
          hash_including(tags: hash_including(source: 'revenuecat_webhook'))
        )
        expect(webhook_event.reload.status).to eq('failed')
        expect(webhook_event.error_message).to include('boom')
      end
    end

    context '未知の event_type を受信したとき' do
      let(:payload) do
        {
          'event' => {
            'id' => event_id,
            'type' => 'UNKNOWN_EVENT_TYPE',
            'app_user_id' => 'user_1'
          }
        }
      end
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: event_id,
               event_type: 'UNKNOWN_EVENT_TYPE',
               payload:)
      end

      it 'Sentry に warning を残しつつ processed として記録する（未対応イベントもキャッシュに残す）' do
        allow(Sentry).to receive(:capture_message)

        process!

        expect(Sentry).to have_received(:capture_message).with(
          a_string_including('UNKNOWN_EVENT_TYPE'),
          hash_including(level: :warning)
        )
        expect(webhook_event.reload.status).to eq('processed')
      end
    end
  end
end
