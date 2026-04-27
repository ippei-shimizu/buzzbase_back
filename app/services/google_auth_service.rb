class GoogleAuthService
  class InvalidToken < StandardError; end

  def self.verify(id_token)
    payload = nil
    allowed_client_ids.each do |client_id|
      payload = Google::Auth::IDTokens.verify_oidc(id_token, aud: client_id)
      break
    rescue Google::Auth::IDTokens::VerificationError
      next
    end

    raise InvalidToken, 'Google IDトークンの検証に失敗しました' unless payload

    {
      email: payload['email'],
      uid: payload['sub'],
      name: payload['name']
    }
  rescue StandardError => e
    raise if e.is_a?(InvalidToken)

    Sentry.capture_exception(e) if Sentry.initialized?
    raise InvalidToken, "Google認証サービスとの通信に失敗しました: #{e.message}"
  end

  def self.allowed_client_ids
    [
      ENV.fetch('GOOGLE_CLIENT_ID'),
      ENV.fetch('GOOGLE_IOS_CLIENT_ID', nil)
    ].compact
  end

  private_class_method :allowed_client_ids
end
