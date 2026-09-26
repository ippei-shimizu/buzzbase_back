class SocialLoginGuidanceMailer < ApplicationMailer
  # 宛先のログイン方式（Google / Apple）を本文に含むため、運営アドレスへの BCC を外す。
  default bcc: nil

  PROVIDER_NAMES = { 'google' => 'Google', 'apple' => 'Apple' }.freeze

  # パスワードリセットを要求したソーシャル連携アカウントに、ソーシャルログインを案内する。
  # @param user [User] provider が google / apple のユーザー
  def password_reset_requested(user)
    @user = user
    @provider_name = PROVIDER_NAMES.fetch(user.provider)
    @password_set = user.encrypted_password.present?
    mail to: user.email
  end
end
