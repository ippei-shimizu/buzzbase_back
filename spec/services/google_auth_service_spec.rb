require 'rails_helper'

RSpec.describe GoogleAuthService do
  let(:client_id) { 'web-client-id.apps.googleusercontent.com' }
  let(:google_uid) { '110000000000000000001' }
  let(:email) { 'google-user@example.com' }
  let(:id_token) { 'valid_id_token' }

  let(:payload) do
    {
      'sub' => google_uid,
      'email' => email,
      'email_verified' => true,
      'name' => '山田 太郎'
    }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GOOGLE_CLIENT_ID').and_return(client_id)
    allow(ENV).to receive(:fetch).with('GOOGLE_IOS_CLIENT_ID', nil).and_return(nil)
    allow(ENV).to receive(:fetch).with('GOOGLE_ANDROID_CLIENT_ID', nil).and_return(nil)
    allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_return(payload)
  end

  describe '.verify' do
    context '正常なトークンの場合' do
      it 'email, uid, nameを返す' do
        result = described_class.verify(id_token)

        expect(result[:email]).to eq(email)
        expect(result[:uid]).to eq(google_uid)
        expect(result[:name]).to eq('山田 太郎')
      end
    end

    context 'email_verifiedが文字列の"true"の場合' do
      let(:payload) do
        {
          'sub' => google_uid,
          'email' => email,
          'email_verified' => 'true',
          'name' => '山田 太郎'
        }
      end

      it 'email, uid, nameを返す' do
        result = described_class.verify(id_token)

        expect(result[:email]).to eq(email)
        expect(result[:uid]).to eq(google_uid)
      end
    end

    context '2つ目のClient IDで検証に成功する場合' do
      let(:ios_client_id) { 'ios-client-id.apps.googleusercontent.com' }

      before do
        allow(ENV).to receive(:fetch).with('GOOGLE_IOS_CLIENT_ID', nil).and_return(ios_client_id)
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(id_token, aud: client_id).and_raise(Google::Auth::IDTokens::VerificationError)
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(id_token, aud: ios_client_id).and_return(payload)
      end

      it 'email, uid, nameを返す' do
        result = described_class.verify(id_token)

        expect(result[:email]).to eq(email)
        expect(result[:uid]).to eq(google_uid)
      end
    end

    context 'email_verifiedがfalseの場合' do
      let(:payload) do
        {
          'sub' => google_uid,
          'email' => email,
          'email_verified' => false,
          'name' => '山田 太郎'
        }
      end

      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(id_token) }.to raise_error(
          described_class::InvalidToken, 'メールアドレスが未検証です'
        )
      end
    end

    context 'email_verifiedが欠落している場合' do
      let(:payload) do
        {
          'sub' => google_uid,
          'email' => email,
          'name' => '山田 太郎'
        }
      end

      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(id_token) }.to raise_error(
          described_class::InvalidToken, 'メールアドレスが未検証です'
        )
      end
    end

    context 'すべてのClient IDで検証に失敗した場合' do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .and_raise(Google::Auth::IDTokens::VerificationError)
      end

      it 'InvalidTokenを発生させる' do
        expect { described_class.verify(id_token) }.to raise_error(
          described_class::InvalidToken, 'Google IDトークンの検証に失敗しました'
        )
      end
    end
  end
end
