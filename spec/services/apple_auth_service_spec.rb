require 'rails_helper'

RSpec.describe AppleAuthService do
  let(:apple_private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:bundle_id) { 'jp.buzzbase.mobile' }
  let(:apple_user_id) { '001234.abcdef1234567890.1234' }
  let(:email) { 'test@privaterelay.appleid.com' }

  let(:valid_payload) do
    {
      'iss' => 'https://appleid.apple.com',
      'aud' => bundle_id,
      'exp' => 1.hour.from_now.to_i,
      'iat' => Time.current.to_i,
      'sub' => apple_user_id,
      'email' => email,
      'email_verified' => 'true',
      'is_private_email' => 'true'
    }
  end

  let(:jwk) { JWT::JWK.new(apple_private_key, kid: 'test-key-id') }
  let(:jwks_set) { JWT::JWK::Set.new(jwk) }

  let(:identity_token) do
    JWT.encode(valid_payload, apple_private_key, 'RS256', { kid: 'test-key-id' })
  end

  before do
    # JWKSキャッシュをリセット
    described_class.instance_variable_set(:@jwks_cache, nil)
    described_class.instance_variable_set(:@jwks_cache_expires_at, nil)

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('APPLE_BUNDLE_ID', 'jp.buzzbase.mobile').and_return(bundle_id)

    # Apple JWKSエンドポイントをモック
    allow(Net::HTTP).to receive(:get).with(URI('https://appleid.apple.com/keys')).and_return(
      { 'keys' => [jwk.export] }.to_json
    )
  end

  describe '.verify' do
    context '正常なトークンの場合' do
      it 'uid, email, nameを返す' do
        result = described_class.verify(identity_token)

        expect(result[:uid]).to eq(apple_user_id)
        expect(result[:email]).to eq(email)
        expect(result[:name]).to be_nil
      end

      it 'full_nameが指定された場合はnameを返す' do
        full_name = { given_name: '太郎', family_name: '山田' }
        result = described_class.verify(identity_token, full_name: full_name)

        expect(result[:name]).to eq('山田 太郎')
      end

      it 'full_nameが文字列キーの場合もnameを返す' do
        full_name = { 'given_name' => '太郎', 'family_name' => '山田' }
        result = described_class.verify(identity_token, full_name: full_name)

        expect(result[:name]).to eq('山田 太郎')
      end
    end

    context 'トークンが空の場合' do
      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(nil) }.to raise_error(
          described_class::InvalidToken, 'Apple IDトークンが指定されていません'
        )
      end
    end

    context 'トークンが期限切れの場合' do
      let(:valid_payload) do
        {
          'iss' => 'https://appleid.apple.com',
          'aud' => bundle_id,
          'exp' => 1.hour.ago.to_i,
          'iat' => 2.hours.ago.to_i,
          'sub' => apple_user_id,
          'email' => email
        }
      end

      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(identity_token) }.to raise_error(
          described_class::InvalidToken, /Apple IDトークンの検証に失敗しました/
        )
      end
    end

    context 'audienceが不正な場合' do
      let(:valid_payload) do
        {
          'iss' => 'https://appleid.apple.com',
          'aud' => 'wrong.bundle.id',
          'exp' => 1.hour.from_now.to_i,
          'iat' => Time.current.to_i,
          'sub' => apple_user_id,
          'email' => email
        }
      end

      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(identity_token) }.to raise_error(
          described_class::InvalidToken, /Apple IDトークンの検証に失敗しました/
        )
      end
    end

    context 'JWKS取得に失敗した場合' do
      before do
        allow(Net::HTTP).to receive(:get).and_raise(SocketError, 'Failed to connect')
      end

      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(identity_token) }.to raise_error(
          described_class::InvalidToken, /Apple認証サービスとの通信に失敗しました/
        )
      end
    end
  end
end
