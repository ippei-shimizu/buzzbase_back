class EmailAuthenticationMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.email_authentication_mailer.send_when_signup.subject
  #
  def send_when_signup(user, redirect_url = nil)
    @user = user
    # ユーザー名は登録直後の画面ではなく後続のユーザー名設定画面で入力させる設計のため、
    # 確認メール送信時点では未設定（空）のことがある。
    @greeting = user.name.presence ? "#{user.name} 様" : 'BUZZ BASEにご登録いただきありがとうございます'
    @confirmation_url = api_v1_user_confirmation_url(
      confirmation_token: user.confirmation_token,
      redirect_url: redirect_url || ENV.fetch('CONFIRM_SUCCESS_URL', 'http://localhost:8100/signin')
    )
    mail(
      to: user.email,
      subject: I18n.t('email_subjects.account_confirmation'),
      bcc: 'buzzbase.app@gmail.com'
    )
  end
end
