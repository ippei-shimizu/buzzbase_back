class InternalJwtService
  # NOTE: サーバー間通信用のJWTサービス

  SECRET_KEY = ENV['JWT_SECRET'] || 'fallback-secret-key-for-development'
  ALGORITHM = 'HS256'.freeze
  EXPIRATION_TIME = 1.hour

  class << self
    def encode_token(admin_user_id)
      payload = {
        admin_user_id:,
        iat: Time.current.to_i,
        exp: EXPIRATION_TIME.from_now.to_i,
        iss: 'buzzbase-nextjs',
        aud: 'buzzbase-rails'
      }

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def decode_token(token)
      decoded = JWT.decode(
        token,
        SECRET_KEY,
        true,
        {
          algorithm: ALGORITHM,
          iss: 'buzzbase-nextjs',
          aud: 'buzzbase-rails',
          verify_iss: true,
          verify_aud: true,
          verify_exp: true,
          verify_iat: true
        }
      )

      decoded[0]
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidAudError => e
      Rails.logger.warn "JWT decode error: #{e.message}"
      nil
    end

    def authenticate_admin_user(token)
      payload = decode_token(token)
      return nil unless payload

      admin_user_id = payload['admin_user_id']
      return nil unless admin_user_id

      Admin::User.find_by(id: admin_user_id)
    end
  end
end
