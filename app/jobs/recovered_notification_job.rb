# 課金失敗（billing_issue）から復帰したことをメール + Push で通知する。
# Apple Sign-In + private relay のユーザーはメールが届かないため、Push を主チャネルとして送る。
class RecoveredNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.recovered(user).deliver_now if user.email_deliverable?
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】決済が復旧しました',
      body: '自動更新が正常に再開されました。引き続き Pro 機能をご利用いただけます。'
    )
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
