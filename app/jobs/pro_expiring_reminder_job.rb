# cancelled / billing_issue の Pro 期間が 3 日後に終了するユーザーへリマインダー通知を送る。
# Heroku Scheduler から rake task 経由で毎日 1 回起動される想定。
class ProExpiringReminderJob < ApplicationJob
  queue_as :default

  def perform
    Subscription
      .where(status: %w[cancelled billing_issue])
      .where(expires_at: 3.days.from_now.all_day)
      .find_each { |subscription| notify(subscription.user) }
  end

  private

  def notify(user)
    SubscriptionMailer.pro_expiring_soon(user).deliver_now
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】Pro 期間終了 3 日前',
      body: 'あと 3 日で Pro 機能が終了します。継続する場合は決済情報や再加入手続きをご確認ください。'
    )
  rescue StandardError => e
    Sentry.capture_exception(e, tags: { source: 'pro_expiring_reminder', user_id: user.id })
  end
end
