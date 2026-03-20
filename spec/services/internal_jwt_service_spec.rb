require 'rails_helper'

RSpec.describe InternalJwtService do
  let(:admin_user) do
    Admin::User.create!(
      email: 'admin@example.com',
      password: 'password123',
      name: 'Admin User'
    )
  end

  describe '.encode_access_token' do
    it 'returns a JWT string' do
      token = described_class.encode_access_token(admin_user.id)

      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'encodes the admin_user_id in the payload' do
      token = described_class.encode_access_token(admin_user.id)
      payload = described_class.decode_token(token)

      expect(payload['admin_user_id']).to eq(admin_user.id)
    end

    it 'sets token_type to access' do
      token = described_class.encode_access_token(admin_user.id)
      payload = described_class.decode_token(token)

      expect(payload['token_type']).to eq('access')
    end
  end

  describe '.create_refresh_token' do
    it 'returns a hash with token and record' do
      result = described_class.create_refresh_token(admin_user.id)

      expect(result).to have_key(:token)
      expect(result).to have_key(:record)
      expect(result[:token]).to be_a(String)
      expect(result[:record]).to be_a(Admin::RefreshToken)
    end

    it 'creates an Admin::RefreshToken record in the database' do
      expect { described_class.create_refresh_token(admin_user.id) }
        .to change(Admin::RefreshToken, :count).by(1)
    end

    it 'sets token_type to refresh in the encoded token' do
      result = described_class.create_refresh_token(admin_user.id)
      payload = described_class.decode_token(result[:token])

      expect(payload['token_type']).to eq('refresh')
    end

    it 'sets a jti that matches the stored record' do
      result = described_class.create_refresh_token(admin_user.id)
      payload = described_class.decode_token(result[:token])

      expect(result[:record].jti).to eq(payload['jti'])
    end
  end

  describe '.decode_token' do
    it 'decodes a valid access token and returns payload' do
      token = described_class.encode_access_token(admin_user.id)
      payload = described_class.decode_token(token)

      expect(payload).to be_a(Hash)
      expect(payload['admin_user_id']).to eq(admin_user.id)
      expect(payload['iss']).to eq('buzzbase-nextjs')
      expect(payload['aud']).to eq('buzzbase-rails')
    end

    it 'returns nil for an invalid token' do
      payload = described_class.decode_token('invalid.token.here')

      expect(payload).to be_nil
    end

    it 'returns nil for an expired token' do
      expired_token = JWT.encode(
        {
          admin_user_id: admin_user.id,
          token_type: 'access',
          iat: 1.hour.ago.to_i,
          exp: 30.minutes.ago.to_i,
          iss: 'buzzbase-nextjs',
          aud: 'buzzbase-rails'
        },
        InternalJwtService::SECRET_KEY,
        InternalJwtService::ALGORITHM
      )

      payload = described_class.decode_token(expired_token)

      expect(payload).to be_nil
    end

    it 'returns nil for a token with wrong issuer' do
      wrong_iss_token = JWT.encode(
        {
          admin_user_id: admin_user.id,
          token_type: 'access',
          iat: Time.current.to_i,
          exp: 15.minutes.from_now.to_i,
          iss: 'wrong-issuer',
          aud: 'buzzbase-rails'
        },
        InternalJwtService::SECRET_KEY,
        InternalJwtService::ALGORITHM
      )

      payload = described_class.decode_token(wrong_iss_token)

      expect(payload).to be_nil
    end

    it 'returns nil for a token with wrong audience' do
      wrong_aud_token = JWT.encode(
        {
          admin_user_id: admin_user.id,
          token_type: 'access',
          iat: Time.current.to_i,
          exp: 15.minutes.from_now.to_i,
          iss: 'buzzbase-nextjs',
          aud: 'wrong-audience'
        },
        InternalJwtService::SECRET_KEY,
        InternalJwtService::ALGORITHM
      )

      payload = described_class.decode_token(wrong_aud_token)

      expect(payload).to be_nil
    end
  end

  describe '.authenticate_admin_user' do
    context 'with a valid access token' do
      it 'returns the Admin::User' do
        token = described_class.encode_access_token(admin_user.id)
        result = described_class.authenticate_admin_user(token)

        expect(result).to eq(admin_user)
      end
    end

    context 'with a valid refresh token' do
      it 'returns the Admin::User' do
        refresh_result = described_class.create_refresh_token(admin_user.id)
        result = described_class.authenticate_admin_user(refresh_result[:token])

        expect(result).to eq(admin_user)
      end
    end

    context 'with an invalid token' do
      it 'returns nil' do
        result = described_class.authenticate_admin_user('invalid.token')

        expect(result).to be_nil
      end
    end

    context 'when admin user does not exist' do
      it 'returns nil' do
        token = described_class.encode_access_token(99_999_999)
        result = described_class.authenticate_admin_user(token)

        expect(result).to be_nil
      end
    end
  end

  describe '.validate_refresh_token' do
    context 'with a valid refresh token' do
      it 'returns the Admin::User' do
        refresh_result = described_class.create_refresh_token(admin_user.id)
        result = described_class.validate_refresh_token(refresh_result[:token])

        expect(result).to eq(admin_user)
      end
    end

    context 'with an access token (not a refresh token)' do
      it 'returns nil' do
        access_token = described_class.encode_access_token(admin_user.id)
        result = described_class.validate_refresh_token(access_token)

        expect(result).to be_nil
      end
    end

    context 'with a revoked refresh token' do
      it 'returns nil' do
        refresh_result = described_class.create_refresh_token(admin_user.id)
        refresh_result[:record].revoke!

        result = described_class.validate_refresh_token(refresh_result[:token])

        expect(result).to be_nil
      end
    end

    context 'with an invalid token' do
      it 'returns nil' do
        result = described_class.validate_refresh_token('invalid.token')

        expect(result).to be_nil
      end
    end
  end
end
