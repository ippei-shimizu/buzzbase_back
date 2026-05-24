require 'rails_helper'

RSpec.describe SubscriptionCancelledNotificationJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    it 'SubscriptionMailer.cancelled を deliver_now で送信する' do
      mail = instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
      allow(SubscriptionMailer).to receive(:cancelled).with(user).and_return(mail)

      described_class.new.perform(user.id)

      expect(SubscriptionMailer).to have_received(:cancelled).with(user)
      expect(mail).to have_received(:deliver_now)
    end

    context 'user_id が見つからないとき' do
      it '例外を投げず処理を終える' do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end

    context 'メール送信で例外が発生したとき' do
      before do
        allow(SubscriptionMailer).to receive(:cancelled).and_raise(StandardError, 'smtp down')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'fire-and-forget で例外を握り潰し Sentry に通知する' do
        expect { described_class.new.perform(user.id) }.not_to raise_error

        expect(Sentry).to have_received(:capture_exception).with(
          instance_of(StandardError),
          hash_including(tags: hash_including(source: 'subscription_notification', user_id: user.id))
        )
      end
    end
  end
end
