class CustomConfirmationsController < DeviseTokenAuth::ConfirmationsController
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

  def default_redirect_url
    ENV['CONFIRM_SUCCESS_URL'].presence || '/signin'
  end

  def validate_redirect_url(redirect_url)
    return default_redirect_url if redirect_url.blank?

    # ホワイトリスト: 環境変数で指定されたホストのみ許可
    allowed_hosts = [
      ENV.fetch('FRONTEND_URL', nil),
      ENV.fetch('CONFIRM_SUCCESS_URL', nil)
    ].compact.map { |url| URI.parse(url).host }

    uri = URI.parse(redirect_url)

    if allowed_hosts.include?(uri.host)
      redirect_url
    else
      # 不正なリダイレクト先をブロック
      Rails.logger.warn("Blocked redirect to unauthorized host: #{uri.host}. Allowed: #{allowed_hosts.inspect}")
      default_redirect_url
    end
  rescue URI::InvalidURIError => e
    Rails.logger.error("Invalid redirect URL: #{redirect_url} - #{e.message}")
    default_redirect_url
  end

  def add_query_param(url, key, value)
    return default_redirect_url if url.blank?

    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || '') << [key, value]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  rescue URI::InvalidURIError => e
    Rails.logger.error("Invalid URL in add_query_param: #{url} - #{e.message}")
    default_redirect_url
  end
end
