require 'rails_helper'

RSpec.describe ProExpiringReminderJob, type: :job do
  let(:job) { described_class.new }

  before do
    allow(SubscriptionMailer).to receive(:pro_expiring_soon) do |_user|
      instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
    end
    allow(PushNotificationService).to receive(:send_to_user)
  end

  describe '#perform' do
    context '3 日後に期限切れる cancelled ユーザー' do
      let!(:cancelled_user) do
        user = create(:user)
        user.subscription.update!(status: 'cancelled', expires_at: 3.days.from_now.beginning_of_day + 6.hours, cancelled_at: 2.days.ago)
        user
      end

      it 'メール送信 + 再加入を促す Push を送信する' do
        job.perform
        expect(SubscriptionMailer).to have_received(:pro_expiring_soon).with(cancelled_user)
        expect(PushNotificationService).to have_received(:send_to_user).with(
          cancelled_user,
          hash_including(body: a_string_including('再加入'))
        )
      end
    end

    context '3 日後に期限切れる cancelled ユーザーが private relay アドレスのとき' do
      let!(:relay_user) do
        user = create(:user, email: 'abc.def@privaterelay.appleid.com')
        user.subscription.update!(status: 'cancelled', expires_at: 3.days.from_now.beginning_of_day + 6.hours, cancelled_at: 2.days.ago)
        user
      end

      it 'メールはスキップし Push のみ送信する' do
        job.perform
        expect(SubscriptionMailer).not_to have_received(:pro_expiring_soon)
        expect(PushNotificationService).to have_received(:send_to_user).with(relay_user, hash_including(:title, :body))
      end
    end

    context '3 日後に期限切れる billing_issue ユーザー' do
      let!(:billing_issue_user) do
        user = create(:user)
        user.subscription.update!(status: 'billing_issue', expires_at: 3.days.from_now.beginning_of_day + 8.hours,
                                  billing_issue_at: 1.day.ago)
        user
      end

      it 'メール送信 + 決済情報更新を促す Push を送信する' do
        job.perform
        expect(SubscriptionMailer).to have_received(:pro_expiring_soon).with(billing_issue_user)
        expect(PushNotificationService).to have_received(:send_to_user).with(
          billing_issue_user,
          hash_including(body: a_string_including('決済情報を更新'))
        )
      end
    end

    context 'status が trial / active / expired のとき' do
      before do
        create(:user).subscription.update!(status: 'trial', expires_at: 3.days.from_now)
        create(:user).subscription.update!(status: 'active', expires_at: 3.days.from_now)
        create(:user).subscription.update!(status: 'expired', expires_at: 3.days.from_now)
      end

      it '対象外として通知しない' do
        job.perform
        expect(SubscriptionMailer).not_to have_received(:pro_expiring_soon)
      end
    end
  end
end
