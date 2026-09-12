class CustomConfirmationsController < DeviseTokenAuth::ConfirmationsController
  include RedirectUrlWhitelistable

  def show
    @resource = resource_class.confirm_by_token(params[:confirmation_token])

    # validate_redirect_urlでホワイトリスト検証済みのURLを取得
    redirect_url = your_custom_path(@resource)
    if @resource.errors.empty?
      # 確認成功パラメータを追加
      redirect_url_with_params = add_query_param(redirect_url, 'account_confirmation_success', 'true')
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

  def your_custom_path(_resource)
    redirect_url = params[:redirect_url] || default_redirect_url

    validate_redirect_url(redirect_url)
  end
end
