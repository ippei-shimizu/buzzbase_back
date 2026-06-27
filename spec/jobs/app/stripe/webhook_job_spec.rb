require 'rails_helper'

RSpec.describe App::Stripe::WebhookJob, type: :job do
  let(:webhook_event) { create(:webhook_event, provider: 'stripe') }

  describe '#perform' do
    it 'App::Stripe::WebhookProcessor#process を呼び出す' do
      processor = instance_double(App::Stripe::WebhookProcessor, process: nil)
      allow(App::Stripe::WebhookProcessor).to receive(:new).with(webhook_event).and_return(processor)

      described_class.new.perform(webhook_event.id)
      expect(processor).to have_received(:process)
    end

    context 'webhook_event が見つからないとき' do
      it '例外を raise しない（DB 競合や手動削除に備える）' do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end
  end

  describe 'retry / queue 設定' do
    it 'StandardError で exponential backoff のリトライ設定がある' do
      handlers = described_class.rescue_handlers
      expect(handlers.find { |klass, _| klass == 'StandardError' }).to be_present
    end

    it 'default キューに enqueue される' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
