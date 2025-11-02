class CustomConfirmationsController < DeviseTokenAuth::ConfirmationsController
  def show
    @resource = resource_class.confirm_by_token(params[:confirmation_token])

    if @resource.errors.empty?
      redirect_url = your_custom_path(@resource)
      # 確認成功パラメータを追加
      redirect_url_with_params = add_query_param(redirect_url, 'account_confirmation_success', 'true')
      redirect_to redirect_url_with_params, allow_other_host: true
    else
      # エラーの場合はリダイレクト先にエラーパラメータを付けて遷移
      redirect_url = your_custom_path(@resource)
      error_message = @resource.errors.full_messages.join(', ')
      redirect_url_with_params = add_query_param(redirect_url, 'account_confirmation_success', 'false')
      redirect_url_with_params = add_query_param(redirect_url_with_params, 'error', error_message)
      redirect_to redirect_url_with_params, allow_other_host: true
    end
  end

  private

  def your_custom_path(_resource)
    params[:redirect_url] || ENV.fetch('CONFIRM_SUCCESS_URL', nil)
  end

  def add_query_param(url, key, value)
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || '') << [key, value]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
