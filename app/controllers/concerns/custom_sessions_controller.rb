class CustomSessionsController < DeviseTokenAuth::SessionsController
  private

  # 標準実装は provider='email' で絞るため、パスワードを設定したソーシャル連携アカウントは見つからない。
  # provider を書き換えるとソーシャルログインで戻されるので、provider は変えずにここで照合対象に加える。
  def find_resource(field, value)
    super || (User.active.social_with_password.find_by(email: value) if field == :email)
  end
end
