class GoogleAuthService
  class InvalidToken < StandardError; end

  def self.verify(id_token)
    validator = GoogleIDToken::Validator.new
    payload = validator.check(id_token, ENV.fetch('GOOGLE_CLIENT_ID'))

    {
      email: payload['email'],
      uid: payload['sub'],
      name: payload['name']
    }
  rescue GoogleIDToken::ValidationError => e
    raise InvalidToken, "Google IDトークンの検証に失敗しました: #{e.message}"
  end
end
