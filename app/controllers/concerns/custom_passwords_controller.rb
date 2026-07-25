class CustomPasswordsController < DeviseTokenAuth::PasswordsController
  include RedirectUrlWhitelistable

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
  # レスポンスを返す。
  def render_not_found_error
    render_create_success
  end
end
