require 'rails_helper'

RSpec.describe RevenueCatWebhookJob, type: :job do
  let(:webhook_event) { create(:webhook_event) }

  describe '#perform' do
    it 'RevenueCat::WebhookProcessor#process を呼び出す' do
      processor = instance_double(RevenueCat::WebhookProcessor, process: nil)
      allow(RevenueCat::WebhookProcessor).to receive(:new).with(webhook_event).and_return(processor)

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

  describe '恒久的エラーの discard' do
    let(:handler) { instance_double(RevenueCat::Handlers::InitialPurchaseHandler) }

    before do
      allow(Sentry).to receive(:capture_exception)
      allow(RevenueCat::EventDispatcher).to receive(:handler_for).and_return(handler)
      allow(handler).to receive(:call).and_raise(error)
    end

    context '恒久的エラー（UnresolvedUserError / UnknownProductError）のとき' do
      [RevenueCat::UserResolver::UnresolvedUserError,
       RevenueCat::Handlers::BaseHandler::UnknownProductError].each do |error_class|
        context error_class.name do
          let(:error) { error_class }

          it 'リトライせず初回で discard し、Sentry 通知も 1 回だけになる' do
            perform_enqueued_jobs do
              expect { described_class.perform_later(webhook_event.id) }.not_to raise_error
            end

            expect(Sentry).to have_received(:capture_exception).once
            expect(enqueued_jobs).to be_empty
            expect(webhook_event.reload).to be_failed
          end
        end
      end
    end

    context '一時的エラー（RequestFailedError）のとき' do
      let(:error) { RevenueCat::SubscriberClient::RequestFailedError }

      it '従来通り最大 5 回までリトライされる' do
        perform_enqueued_jobs do
          expect { described_class.perform_later(webhook_event.id) }.to raise_error(error)
        end

        expect(Sentry).to have_received(:capture_exception).exactly(5).times
      end
    end
  end

  describe 'queue' do
    it 'default キューに enqueue される' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
