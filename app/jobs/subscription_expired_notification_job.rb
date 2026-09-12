# Pro 期限切れ時にメール + Push 通知でユーザーに伝える。
class SubscriptionExpiredNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.expired(user).deliver_now if user.email_deliverable?
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】Pro 期間が終了しました',
      body: '無料プランに切り替わりました。再加入で過去のデータがすぐに復活します。'
    )
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
