require 'rails_helper'

RSpec.describe RecoveredNotificationJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    it 'SubscriptionMailer.recovered を deliver_now で送信する（Push なし）' do
      mail = instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
      allow(SubscriptionMailer).to receive(:recovered).with(user).and_return(mail)
      allow(PushNotificationService).to receive(:send_to_user)

      described_class.new.perform(user.id)

      expect(mail).to have_received(:deliver_now)
      expect(PushNotificationService).not_to have_received(:send_to_user)
    end

    context 'user_id が見つからないとき' do
      it '例外を投げず処理を終える' do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end
  end
end
