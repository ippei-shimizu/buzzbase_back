# トライアル終了 3 日前のユーザーへリマインダー通知を送る。
# Heroku Scheduler から rake task 経由で毎日 1 回起動される想定。
class TrialExpiringReminderJob < ApplicationJob
  queue_as :default

  def perform
    Subscription
      .includes(:user)
      .where(status: 'trial')
      .where(expires_at: 3.days.from_now.all_day)
      .find_each { |subscription| notify(subscription.user) }
  end

  private

  def notify(user)
    SubscriptionMailer.trial_expiring_soon(user).deliver_now if user.email_deliverable?
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】トライアル終了 3 日前',
      body: 'あと 3 日でトライアル期間が終了し、自動課金が始まります。'
    )
  rescue StandardError => e
    # 1 ユーザー失敗で他のユーザー処理を中断しないため握り潰す。
    Sentry.capture_exception(e, tags: { source: 'trial_expiring_reminder', user_id: user.id })
  end
end
