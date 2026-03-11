class GoogleAuthService
  class InvalidToken < StandardError; end

  def self.verify(id_token)
    payload = Google::Auth::IDTokens.verify_oidc(id_token, aud: ENV.fetch('GOOGLE_CLIENT_ID'))

    {
      email: payload['email'],
      uid: payload['sub'],
      name: payload['name']
    }
  rescue Google::Auth::IDTokens::VerificationError => e
    raise InvalidToken, "Google IDトークンの検証に失敗しました: #{e.message}"
  rescue StandardError => e
    raise InvalidToken, "Google認証サービスとの通信に失敗しました: #{e.message}"
  end
end
