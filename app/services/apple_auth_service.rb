require 'net/http'
require 'jwt'

class AppleAuthService
  class InvalidToken < StandardError; end

  APPLE_JWKS_URI = 'https://appleid.apple.com/keys'
  APPLE_ISSUER = 'https://appleid.apple.com'
  JWKS_CACHE_TTL = 24.hours

  def self.verify(identity_token, full_name: nil)
    raise InvalidToken, 'Apple IDトークンが指定されていません' if identity_token.blank?

    payload, = JWT.decode(
      identity_token,
      nil,
      true,
      {
        algorithms: ['RS256'],
        jwks: jwks,
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
      name: name
    }
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidAudError => e
    raise InvalidToken, "Apple IDトークンの検証に失敗しました: #{e.message}"
  rescue StandardError => e
    raise InvalidToken, "Apple認証サービスとの通信に失敗しました: #{e.message}" unless e.is_a?(InvalidToken)

    raise
  end

  def self.jwks
    if @jwks_cache.nil? || @jwks_cache_expires_at.nil? || @jwks_cache_expires_at < Time.current
      uri = URI(APPLE_JWKS_URI)
      response = Net::HTTP.get(uri)
      @jwks_cache = JWT::JWK::Set.new(JSON.parse(response))
      @jwks_cache_expires_at = Time.current + JWKS_CACHE_TTL
    end
    @jwks_cache
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

  private_class_method :jwks, :build_name, :bundle_id
end
