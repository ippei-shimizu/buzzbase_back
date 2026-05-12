class PushNotificationService
  EXPO_BATCH_SIZE = 100

  # 指定ユーザーの全デバイストークンにプッシュ通知を送信する。
  # @param user [User] 通知対象ユーザー
  # @param title [String] 通知タイトル
  # @param body [String] 通知本文
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

  # 全ユーザーの全端末トークンへプッシュ通知を一斉送信する。
  # Expo Push APIの100件制限に対応するため、EXPO_BATCH_SIZE ずつ分割して送信する。
  #
  # NOTE: DeviceToken が 10,000 件を超える規模になったら、Jobをバッチ単位に分割し
  # Sidekiq 導入で並列実行することを検討する。1,000 ユーザー（~1,200 トークン）規模なら
  # 約5秒で完了する想定。
  #
  # @param title [String] 通知タイトル
  # @param body [String] 通知本文
  def self.send_to_all(title:, body:)
    client = Exponent::Push::Client.new
    token_batch = []

    DeviceToken.find_each(batch_size: 1000) do |device_token|
      token_batch << device_token.token
      if token_batch.size >= EXPO_BATCH_SIZE
        send_batch(client, token_batch, title:, body:)
        token_batch = []
      end
    end

    send_batch(client, token_batch, title:, body:) if token_batch.any?
  end

  # 1バッチ（最大EXPO_BATCH_SIZE件）を送信する。
  # Expo APIから返されたエラーレシートはSentryに警告として送り、無効トークンの削除は行わない。
  def self.send_batch(client, tokens, title:, body:)
    messages = tokens.map { |token| { to: token, title:, body:, sound: 'default' } }
    handler = client.send_messages(messages)

    if handler.errors?
      Rails.logger.error("PushNotificationService.send_to_all errors: #{handler.errors.inspect}")
      if Sentry.initialized?
        Sentry.capture_message(
          'Push notification batch errors',
          level: :warning,
          extra: { errors: handler.errors, invalid_tokens: handler.invalid_push_tokens }
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error("PushNotificationService.send_batch failed: #{e.message}")
    Sentry.capture_exception(e, extra: { title:, token_count: tokens.size }) if Sentry.initialized?
    raise
  end
  private_class_method :send_batch
end
