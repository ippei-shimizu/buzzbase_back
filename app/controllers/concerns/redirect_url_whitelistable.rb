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

  # 複数パラメータを1回の URI 組み立てで付与する。
  # 1件ずつ add_query_param で畳み込むと、途中で InvalidURIError になった時点で
  # アキュムレータが default_redirect_url に差し替わり、残りのパラメータが
  # API 自身のホスト上の URL に載ってしまう（認証トークンの付与で問題になる）。
  # @return [String, nil] 付与後の URL。組み立てに失敗した場合は nil
  def add_query_params(url, params)
    return nil if url.blank?

    uri = URI.parse(url)
    query_params = URI.decode_www_form(uri.query || '') + params.map { |key, value| [key.to_s, value.to_s] }
    uri.query = URI.encode_www_form(query_params)
    uri.to_s
  rescue URI::InvalidURIError => e
    Rails.logger.error("Invalid URL in add_query_params: #{url} - #{e.message}")
    nil
  end

  def add_query_param(url, key, value)
    add_query_params(url, key => value) || default_redirect_url
  end
end
