# Pro 解約申請完了時にユーザーへメール通知する。
# 同期呼び出し (perform_now) されることがあるため、例外を握り潰し Webhook 全体を巻き込まない設計とする。
class SubscriptionCancelledNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.cancelled(user).deliver_now
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
