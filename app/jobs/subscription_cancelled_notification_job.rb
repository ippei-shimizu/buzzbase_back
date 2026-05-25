# Pro 解約申請完了時にユーザーへメール + Push 通知する。
# 同期呼び出し (perform_now) されることがあるため、例外を握り潰し Webhook 全体を巻き込まない設計とする。
# Apple Sign-In + private relay のユーザーはメールが事実上届かないため、Push を主チャネルとして送る。
class SubscriptionCancelledNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.cancelled(user).deliver_now if user.email_deliverable?
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】解約手続きを受け付けました',
      body: '次回課金日まで Pro 機能を引き続きご利用いただけます。'
    )
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
