class SubscriptionMailer < ApplicationMailer
  # 課金関連メールは個人情報（加入状態 / 課金失敗 / 返金等）を含むため、
  # 運営アドレスへの BCC を外す。
  default bcc: nil

  def trial_expiring_soon(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end

  def pro_expiring_soon(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end

  def cancelled(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end

  def expired(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end

  def billing_issue(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end

  def refunded(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end

  def recovered(user)
    @user = user
    @subscription = user.subscription
    mail to: user.email
  end
end
