require 'rails_helper'

RSpec.describe TrialExpiringReminderJob, type: :job do
  let(:job) { described_class.new }

  before do
    allow(SubscriptionMailer).to receive(:trial_expiring_soon) do |_user|
      instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
    end
    allow(PushNotificationService).to receive(:send_to_user)
  end

  describe '#perform' do
    context '3 日後ピッタリに期限切れる trial ユーザーが居るとき' do
      let!(:target_user) do
        user = create(:user)
        user.subscription.update!(status: 'trial', expires_at: 3.days.from_now + 12.hours)
        user
      end

      it '対象ユーザーへメールと Push を送信する' do
        job.perform
        expect(SubscriptionMailer).to have_received(:trial_expiring_soon).with(target_user)
        expect(PushNotificationService).to have_received(:send_to_user).with(target_user, hash_including(:title, :body))
      end
    end

    context '期限が 3 日後の範囲外のとき' do
      before do
        create(:user).subscription.update!(status: 'trial', expires_at: 5.days.from_now)
        create(:user).subscription.update!(status: 'trial', expires_at: 1.day.from_now)
      end

      it '対象外として通知しない' do
        job.perform
        expect(SubscriptionMailer).not_to have_received(:trial_expiring_soon)
      end
    end

    context 'status が trial 以外のとき' do
      before do
        create(:user).subscription.update!(status: 'active', expires_at: 3.days.from_now)
        create(:user).subscription.update!(status: 'cancelled', expires_at: 3.days.from_now)
      end

      it '対象外として通知しない' do
        job.perform
        expect(SubscriptionMailer).not_to have_received(:trial_expiring_soon)
      end
    end

    context '1 ユーザーへの送信が例外を投げたとき' do
      let!(:failing_user) do
        user = create(:user)
        user.subscription.update!(status: 'trial', expires_at: 3.days.from_now + 12.hours)
        user
      end
      let!(:other_user) do
        user = create(:user)
        user.subscription.update!(status: 'trial', expires_at: 3.days.from_now + 13.hours)
        user
      end

      before do
        allow(SubscriptionMailer).to receive(:trial_expiring_soon).with(failing_user).and_raise(StandardError, 'smtp down')
        allow(SubscriptionMailer).to receive(:trial_expiring_soon).with(other_user).and_return(
          instance_double(ActionMailer::MessageDelivery, deliver_now: nil)
        )
        allow(Sentry).to receive(:capture_exception)
      end

      it '他ユーザー処理は継続し、失敗は Sentry に通知する' do
        expect { job.perform }.not_to raise_error
        expect(SubscriptionMailer).to have_received(:trial_expiring_soon).with(other_user)
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end
end
