# 決済失敗時にメール + Push 通知で決済情報の更新を促す。
class BillingIssueNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.billing_issue(user).deliver_now
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】決済情報を確認してください',
      body: '自動更新で決済が完了できませんでした。お支払い方法をご確認ください。'
    )
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
