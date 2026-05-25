require 'rails_helper'

RSpec.describe RecoveredNotificationJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    let(:mail) { instance_double(ActionMailer::MessageDelivery, deliver_now: nil) }

    before do
      allow(SubscriptionMailer).to receive(:recovered).with(user).and_return(mail)
      allow(PushNotificationService).to receive(:send_to_user)
    end

    it 'メール + Push 通知を同期送信する' do
      described_class.new.perform(user.id)

      expect(mail).to have_received(:deliver_now)
      expect(PushNotificationService).to have_received(:send_to_user)
        .with(user, hash_including(:title, :body))
    end

    context 'Apple private relay のユーザー' do
      let(:user) { create(:user, email: 'abc.def@privaterelay.appleid.com') }

      it 'メールはスキップし Push のみ送信する' do
        described_class.new.perform(user.id)

        expect(SubscriptionMailer).not_to have_received(:recovered)
        expect(PushNotificationService).to have_received(:send_to_user)
      end
    end

    context 'user_id が見つからないとき' do
      it '例外を投げず処理を終える' do
        expect { described_class.new.perform(0) }.not_to raise_error
      end
    end
  end
end
