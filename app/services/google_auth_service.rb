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

    # 未検証メールを通すと、同じメールで登録済みの既存アカウントに provider/uid が
    # リンクされて乗っ取りになりうる。
    raise InvalidToken, 'メールアドレスが未検証です' unless email_verified?(payload)

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

  # Google は boolean で返すが、他の OIDC プロバイダに揃えて文字列も許容する。
  def self.email_verified?(payload)
    payload['email_verified'] == true || payload['email_verified'] == 'true'
  end

  private_class_method :email_verified?

  # Google IDトークンの audience として許容する Client ID 一覧。
  # iOS は iosClientId を使うため aud=iOS Client ID。
  # Android は @react-native-google-signin/google-signin が webClientId を使うため
  # 通常 aud=Web Client ID になるが、ライブラリ設定によっては Android Client ID で
  # 来るケースもあるため両方を許容する。
  def self.allowed_client_ids
    [
      ENV.fetch('GOOGLE_CLIENT_ID'),
      ENV.fetch('GOOGLE_IOS_CLIENT_ID', nil),
      ENV.fetch('GOOGLE_ANDROID_CLIENT_ID', nil)
    ].compact
  end

  private_class_method :allowed_client_ids
end
