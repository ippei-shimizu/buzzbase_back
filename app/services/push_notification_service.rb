class PushNotificationService
  def self.send_to_user(user, title:, body:)
    tokens = user.device_tokens.pluck(:token)
    return if tokens.empty?

    client = Exponent::Push::Client.new
    messages = tokens.map do |token|
      {
        to: token,
        title:,
        body:,
        sound: 'default'
      }
    end

    client.send_messages(messages)
  rescue StandardError => e
    Rails.logger.error("Push notification failed: #{e.message}")
    Sentry.capture_exception(e, extra: { user_id: user.id, title:, token_count: tokens&.size }) if Sentry.initialized?
  end
end
