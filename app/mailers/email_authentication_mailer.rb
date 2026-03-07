class EmailAuthenticationMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.email_authentication_mailer.send_when_signup.subject
  #
  def send_when_signup(user)
    @user = user
    @name = user.name
    @confirmation_url = api_v1_user_confirmation_url(
      confirmation_token: user.confirmation_token,
      redirect_url: ENV.fetch('CONFIRM_SUCCESS_URL', 'http://localhost:8100/signin')
    )
    mail(
      to: user.email,
      subject: I18n.t('email_subjects.account_confirmation'),
      bcc: 'buzzbase.app@gmail.com'
    )
  end
end
