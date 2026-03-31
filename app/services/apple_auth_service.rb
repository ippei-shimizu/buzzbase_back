require 'net/http'
require 'jwt'

class AppleAuthService
  class InvalidToken < StandardError; end

  APPLE_JWKS_URI = 'https://appleid.apple.com/auth/keys'.freeze
  APPLE_ISSUER = 'https://appleid.apple.com'.freeze
  JWKS_CACHE_TTL = 24.hours

  def self.verify(identity_token, full_name: nil)
    raise InvalidToken, 'Apple IDトークンが指定されていません' if identity_token.blank?

    payload, = JWT.decode(
      identity_token,
      nil,
      true,
      {
        algorithms: ['RS256'],
        jwks:,
        iss: APPLE_ISSUER,
        verify_iss: true,
        aud: bundle_id,
        verify_aud: true
      }
    )

    name = build_name(full_name)

    {
      email: payload['email'],
      uid: payload['sub'],
      name:
    }
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidAudError => e
    raise InvalidToken, "Apple IDトークンの検証に失敗しました: #{e.message}"
  rescue StandardError => e
    raise InvalidToken, "Apple認証サービスとの通信に失敗しました: #{e.message}" unless e.is_a?(InvalidToken)

    raise
  end

  def self.jwks
    if @jwks_cache.nil? || @jwks_cache_expires_at.nil? || @jwks_cache_expires_at < Time.current
      response = fetch_jwks
      @jwks_cache = JWT::JWK::Set.new(JSON.parse(response))
      @jwks_cache_expires_at = Time.current + JWKS_CACHE_TTL
    end
    @jwks_cache
  end

  def self.fetch_jwks
    uri = URI(APPLE_JWKS_URI)
    response = request_with_redirect(uri)
    response.body
  end

  def self.request_with_redirect(uri, limit = 3)
    raise InvalidToken, 'リダイレクトが多すぎます' if limit <= 0

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection)
      request_with_redirect(URI(response['location']), limit - 1)
    else
      response
    end
  end

  def self.build_name(full_name)
    return nil if full_name.blank?

    given = full_name[:given_name].presence || full_name['given_name'].presence
    family = full_name[:family_name].presence || full_name['family_name'].presence
    [family, given].compact.join(' ').presence
  end

  def self.bundle_id
    ENV.fetch('APPLE_BUNDLE_ID', 'jp.buzzbase.mobile')
  end

  private_class_method :jwks, :fetch_jwks, :request_with_redirect, :build_name, :bundle_id
end
