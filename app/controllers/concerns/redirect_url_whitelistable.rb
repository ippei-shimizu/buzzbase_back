# メール内リンクのリダイレクト先を検証する共通ロジック。CustomConfirmationsController /
# CustomPasswordsController の双方から使われるオープンリダイレクト対策。
module RedirectUrlWhitelistable
  extend ActiveSupport::Concern

  private

  def default_redirect_url
    ENV['CONFIRM_SUCCESS_URL'].presence || '/signin'
  end

  # モバイルのカスタムスキームと、FRONTEND_URL / CONFIRM_SUCCESS_URL のホストのみ許可する。
  # 不正な値は例外を投げず default_redirect_url に静かにフォールバックする。
  def validate_redirect_url(redirect_url)
    return default_redirect_url if redirect_url.blank?

    uri = URI.parse(redirect_url)

    allowed_schemes = [ENV.fetch('MOBILE_APP_SCHEME', 'buzzbase')]
    return redirect_url if allowed_schemes.include?(uri.scheme)

    allowed_hosts = [
      ENV.fetch('FRONTEND_URL', nil),
      ENV.fetch('CONFIRM_SUCCESS_URL', nil)
    ].compact.map { |url| URI.parse(url).host }

    if allowed_hosts.include?(uri.host)
      redirect_url
    else
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
    query_params = URI.decode_www_form(uri.query || '') << [key, value]
    uri.query = URI.encode_www_form(query_params)
    uri.to_s
  rescue URI::InvalidURIError => e
    Rails.logger.error("Invalid URL in add_query_param: #{url} - #{e.message}")
    default_redirect_url
  end
end
