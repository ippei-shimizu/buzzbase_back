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

  describe '恒久的エラーの discard' do
    let(:handler) { instance_double(App::Stripe::Handlers::CheckoutSessionCompletedHandler) }

    before do
      allow(Sentry).to receive(:capture_exception)
      allow(App::Stripe::EventDispatcher).to receive(:handler_for).and_return(handler)
      allow(handler).to receive(:call).and_raise(error)
    end

    context '恒久的エラー（MissingMetadataError / UnresolvedUserError）のとき' do
      [App::Stripe::Handlers::CheckoutSessionCompletedHandler::MissingMetadataError,
       App::Stripe::Handlers::CheckoutSessionCompletedHandler::UnresolvedUserError].each do |error_class|
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

    context 'App::Stripe::PermanentWebhookError を継承した未知のエラーのとき' do
      # job 側は個別のエラークラスを列挙せず PermanentWebhookError だけを discard_on しているため、
      # 将来 handler 側で新しい恒久的エラーを追加しても job 側の変更なしに discard される。
      let(:error) { Class.new(App::Stripe::PermanentWebhookError) }

      it 'リトライせず初回で discard される' do
        perform_enqueued_jobs do
          expect { described_class.perform_later(webhook_event.id) }.not_to raise_error
        end

        expect(Sentry).to have_received(:capture_exception).once
        expect(enqueued_jobs).to be_empty
        expect(webhook_event.reload).to be_failed
      end
    end

    context '一時的エラー（Stripe API 障害）のとき' do
      let(:error) { Stripe::APIConnectionError }

      it '従来通り最大 5 回までリトライされる' do
        perform_enqueued_jobs do
          expect { described_class.perform_later(webhook_event.id) }.to raise_error(error)
        end

        expect(Sentry).to have_received(:capture_exception).exactly(5).times
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
