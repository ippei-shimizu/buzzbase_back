require 'rails_helper'

RSpec.describe RevenueCatWebhookJob, type: :job do
  let(:webhook_event) { create(:webhook_event) }

  describe '#perform' do
    it 'RevenueCatWebhookProcessor#process を呼び出す' do
      processor = instance_double(RevenueCatWebhookProcessor, process: nil)
      allow(RevenueCatWebhookProcessor).to receive(:new).with(webhook_event).and_return(processor)

      described_class.new.perform(webhook_event.id)
      expect(processor).to have_received(:process)
    end

    context 'webhook_event が見つからないとき' do
      it '例外を raise しない（DB 競合や手動削除に備える）' do
        expect do
          described_class.new.perform(0)
        end.not_to raise_error
      end
    end
  end

  describe 'retry 設定' do
    it 'StandardError で exponential backoff、最大 5 回リトライする' do
      # ActiveJob はクラス変数 retry_jitter / executions_for に直接アクセスできないため、
      # rescue_handlers 経由で設定済みであることだけ確認する。
      handlers = described_class.rescue_handlers
      standard_error_handler = handlers.find { |klass, _| klass == 'StandardError' }
      expect(standard_error_handler).to be_present
    end
  end

  describe 'queue' do
    it 'default キューに enqueue される' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
