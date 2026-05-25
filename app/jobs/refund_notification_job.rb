# 返金完了時にメール通知する。
# Push は送らない: 返金はユーザーが Apple/Stripe で申請した結果であり、
# それぞれの決済プロバイダから別途通知が届くため二重通知を避ける。
class RefundNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.refunded(user).deliver_now
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
