class CustomConfirmationsController < DeviseTokenAuth::ConfirmationsController
  include RedirectUrlWhitelistable

  def show
    @resource = resource_class.confirm_by_token(params[:confirmation_token])

    # validate_redirect_urlでホワイトリスト検証済みのURLを取得
    redirect_url = your_custom_path(@resource)
    if @resource.errors.empty?
      redirect_url_with_params = success_redirect_url(redirect_url)
    else
      # エラーの場合はリダイレクト先にエラーパラメータを付けて遷移
      error_message = @resource.errors.full_messages.join(', ')
      redirect_url_with_params = add_query_param(redirect_url, 'account_confirmation_success', 'false')
      redirect_url_with_params = add_query_param(redirect_url_with_params, 'error', error_message)
    end
    # allow_other_host: true は必要（フロントエンドへのリダイレクトのため）
    # セキュリティ: ホワイトリスト検証済みのため安全
    redirect_to redirect_url_with_params, allow_other_host: true
  end

  private

  # 確認成功時は認証トークンを発行し、リダイレクト URL のクエリに載せる。
  # front / mobile がこれを読んでそのままログイン状態にするため、メール確認後の手動再ログインが不要になる。
  # gem 既定の show はサインイン済みのときだけトークンを発行するので、メールリンク経由では発行されない。
  #
  # 付与には build_auth_url / build_redirect_headers を使わない。前者が内部で呼ぶ
  # DeviseTokenAuth::Url.generate は scheme と host から URL を組み直すため、
  # CONFIRM_SUCCESS_URL 未設定時のフォールバック先である相対パス '/signin' が ':///signin' に壊れる。
  # 後者は後方互換のため client_id / token に同じ秘密を二重で載せ、params[:config] をそのまま反射する。
  # @param redirect_url [String] ホワイトリスト検証済みのリダイレクト先
  # @return [String] 認証トークンと account_confirmation_success を含む URL
  def success_redirect_url(redirect_url)
    token = @resource.create_token
    @resource.save!

    auth_params = {
      'access-token' => token.token,
      'client' => token.client,
      'uid' => @resource.uid,
      'expiry' => token.expiry,
      'account_confirmation_success' => true
    }

    add_query_params(redirect_url, auth_params) || confirmation_success_url(redirect_url)
  end

  def confirmation_success_url(redirect_url)
    add_query_param(redirect_url, 'account_confirmation_success', 'true')
  end

  def your_custom_path(_resource)
    redirect_url = params[:redirect_url] || default_redirect_url

    validate_redirect_url(redirect_url)
  end
end
