# 課金失敗（billing_issue）から復帰したことをメール通知する。
# Push は送らない: 復帰は決済プロバイダ側の自動リトライ成功による「良いニュース」で、
# ユーザーが即時のアクションを取る必要が無いためメールで十分。
class RecoveredNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.recovered(user).deliver_now
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
