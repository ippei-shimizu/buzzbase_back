# cancelled / billing_issue の Pro 期間が 3 日後に終了するユーザーへリマインダー通知を送る。
# Heroku Scheduler から rake task 経由で毎日 1 回起動される想定。
# 状態（解約済み or 課金失敗中）でユーザーに求めるアクションが異なるため、メッセージは status で分岐する。
class ProExpiringReminderJob < ApplicationJob
  queue_as :default

  def perform
    Subscription
      .where(status: %w[cancelled billing_issue])
      .where(expires_at: 3.days.from_now.all_day)
      .find_each { |subscription| notify(subscription) }
  end

  private

  def notify(subscription)
    SubscriptionMailer.pro_expiring_soon(subscription.user).deliver_now
    PushNotificationService.send_to_user(
      subscription.user,
      title: '【BUZZ BASE Pro】Pro 期間終了 3 日前',
      body: push_body_for(subscription)
    )
  rescue StandardError => e
    Sentry.capture_exception(e, tags: { source: 'pro_expiring_reminder', user_id: subscription.user_id })
  end

  # cancelled は「再加入」、billing_issue は「決済情報更新」を促す。
  def push_body_for(subscription)
    if subscription.billing_issue?
      'あと 3 日で Pro 機能が終了します。決済情報を更新すると継続できます。'
    else
      'あと 3 日で Pro 機能が終了します。継続を希望される場合は再加入の手続きをお願いします。'
    end
  end
end
