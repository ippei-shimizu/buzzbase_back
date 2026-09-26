class CustomPasswordsController < DeviseTokenAuth::PasswordsController
  include RedirectUrlWhitelistable

  # 標準実装は provider='email' 以外を 422 で弾くため、ソーシャル連携アカウントはここで更新する。
  # email アカウントと同じく現在のパスワードは求めない（check_current_password_before_update が false）。
  def update
    @resource = set_user_by_token
    return super unless @resource&.social_account?

    unless password_resource_params[:password] && password_resource_params[:password_confirmation]
      return render_update_error_missing_password
    end

    if @resource.update(password_resource_params.slice(:password, :password_confirmation))
      render_update_success
    else
      render_update_error
    end
  end

  private

  # 標準実装は redirect_url 欠落/不許可ホストをエラーで弾くが、フロント/モバイルは常に
  # redirect_url を送る想定のため、ここではエラーにせずホワイトリスト検証済みの値へ
  # 静かにフォールバックする（CustomConfirmationsController と同じ方針）。
  def validate_redirect_url_param
    @redirect_url = validate_redirect_url(params.fetch(:redirect_url, default_redirect_url))
  end

  # edit アクションはメールリンククリック時に redirect_url（front等の別ホスト）へ
  # 遷移させるため、Rails 7 のクロスホストリダイレクト制限を明示的に許可する。
  # validate_redirect_url_param でホワイトリスト検証済みのため安全。
  def redirect_options
    { allow_other_host: true }
  end

  # DeviseTokenAuth::Concerns::ResourceFinder#provider は 'email' 固定のため、
  # Google/Apple アカウントのメールアドレスは元々 @resource が見つからず
  # このメソッドに到達する（= render_not_found_error は「存在しないメール」と
  # 「email/password 未使用のアカウント」を区別できない）。
  # アカウント列挙・認証方式の推測を防ぐため、どちらの場合も送信成功と同じ
  # レスポンスを返す。ソーシャル連携アカウントには本人宛てにログイン方法の案内だけ送る。
  def render_not_found_error
    send_social_login_guidance
    render_create_success
  end

  def send_social_login_guidance
    user = User.active.where(provider: SocialLoginGuidanceMailer::PROVIDER_NAMES.keys).find_by(email: @email)
    return unless user&.email_deliverable?

    SocialLoginGuidanceMailer.password_reset_requested(user).deliver_now
  end
end
