class InternalJwtService
  # NOTE: サーバー間通信用のJWTサービス

  SECRET_KEY = ENV['JWT_SECRET'] || 'fallback-secret-key-for-development'
  ALGORITHM = 'HS256'.freeze
  ACCESS_TOKEN_EXPIRATION = 15.minutes
  REFRESH_TOKEN_EXPIRATION = 30.days

  class << self
    def encode_access_token(admin_user_id)
      payload = {
        admin_user_id:,
        token_type: 'access',
        iat: Time.current.to_i,
        exp: ACCESS_TOKEN_EXPIRATION.from_now.to_i,
        iss: 'buzzbase-nextjs',
        aud: 'buzzbase-rails'
      }
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def create_refresh_token(admin_user_id)
      jti = SecureRandom.uuid
      expires_at = REFRESH_TOKEN_EXPIRATION.from_now

      refresh_token_record = Admin::RefreshToken.create!(
        admin_user_id:,
        jti:,
        expires_at:
      )

      payload = {
        jti:,
        token_type: 'refresh',
        iat: Time.current.to_i,
        exp: expires_at.to_i,
        iss: 'buzzbase-nextjs',
        aud: 'buzzbase-rails'
      }

      {
        token: JWT.encode(payload, SECRET_KEY, ALGORITHM),
        record: refresh_token_record
      }
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

      case payload['token_type']
      when 'access'
        admin_user_id = payload['admin_user_id']
        return nil unless admin_user_id

        Admin::User.find_by(id: admin_user_id)
      when 'refresh'
        authenticate_from_refresh_token(payload)
      else
        admin_user_id = payload['admin_user_id']
        return nil unless admin_user_id

        Admin::User.find_by(id: admin_user_id)
      end
    end

    def authenticate_from_refresh_token(payload)
      jti = payload['jti']
      return nil unless jti

      refresh_token = Admin::RefreshToken.active.find_by(jti:)
      refresh_token&.admin_user
    end

    def validate_refresh_token(token)
      payload = decode_token(token)
      return nil unless payload&.dig('token_type') == 'refresh'

      authenticate_from_refresh_token(payload)
    end
  end
end
