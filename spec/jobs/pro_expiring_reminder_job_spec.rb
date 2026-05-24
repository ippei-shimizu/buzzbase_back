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
    context '3 日後に期限切れる cancelled / billing_issue ユーザーが居るとき' do
      let!(:cancelled_user) do
        user = create(:user)
        user.subscription.update!(status: 'cancelled', expires_at: 3.days.from_now + 6.hours, cancelled_at: 2.days.ago)
        user
      end
      let!(:billing_issue_user) do
        user = create(:user)
        user.subscription.update!(status: 'billing_issue', expires_at: 3.days.from_now + 8.hours, billing_issue_at: 1.day.ago)
        user
      end

      it '両方に通知する' do
        job.perform
        expect(SubscriptionMailer).to have_received(:pro_expiring_soon).with(cancelled_user)
        expect(SubscriptionMailer).to have_received(:pro_expiring_soon).with(billing_issue_user)
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
