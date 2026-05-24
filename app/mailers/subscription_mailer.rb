class SubscriptionMailer < ApplicationMailer
  # 課金関連メールは個人情報（加入状態 / 課金失敗 / 返金等）を含むため、
  # 運営アドレスへの BCC を外す。
  default bcc: nil

  def trial_expiring_soon(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】トライアル終了 3 日前のお知らせ'
  end

  def pro_expiring_soon(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】Pro 期間終了 3 日前のお知らせ'
  end

  def cancelled(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】解約申請を受け付けました'
  end

  def expired(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】Pro 期間が終了しました'
  end

  def billing_issue(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】決済情報の確認をお願いします'
  end

  def refunded(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】返金が完了しました'
  end

  def recovered(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email, subject: '【BUZZ BASE Pro】決済が完了し Pro 機能を再開しました'
  end
end
