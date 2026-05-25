# 返金完了時にメール + Push で通知する。
# Apple Sign-In + private relay のユーザーはメールが届かないため、Push を主チャネルとして送る。
# 決済プロバイダ側からも通知が出るが、BUZZ BASE 側でも結果を必ず把握できるよう二重で送信する。
class RefundNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SubscriptionMailer.refunded(user).deliver_now if user.email_deliverable?
    PushNotificationService.send_to_user(
      user,
      title: '【BUZZ BASE Pro】返金処理が完了しました',
      body: 'ご返金が完了しました。詳細は決済プロバイダのご利用明細をご確認ください。'
    )
  rescue StandardError => e
    Sentry.capture_exception(
      e,
      tags: { source: 'subscription_notification', job_class: self.class.name, user_id: }
    )
  end
end
