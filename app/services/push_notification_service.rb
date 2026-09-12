class PushNotificationService
  EXPO_BATCH_SIZE = 100

  # 指定ユーザーの全デバイストークンにプッシュ通知を送信する。
  # @param user [User] 通知対象ユーザー
  # @param title [String] 通知タイトル
  # @param body [String] 通知本文
  def self.send_to_user(user, title:, body:)
    return log_skipped(scope: :user, user_id: user.id, title:) unless delivery_enabled?

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
    return log_skipped(scope: :all, title:) unless delivery_enabled?

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

  # 実際にExpo Push APIへ送信するかを判定する。
  # production 以外では誤爆を防ぐため既定で無効化し、開発時に検証したい場合のみ
  # ENABLE_PUSH_NOTIFICATIONS=true を明示することで有効化できる。
  # test 環境は spec 側で Exponent::Push::Client を stub しているため許可する。
  def self.delivery_enabled?
    return true if Rails.env.production?
    return true if Rails.env.test?

    ENV['ENABLE_PUSH_NOTIFICATIONS'] == 'true'
  end
  private_class_method :delivery_enabled?

  # 送信をスキップした際の理由を可観測な形でログに残す。
  # Sentry には breadcrumb として残し、後から「ローカルから送信を試みたか」を追跡できるようにする。
  def self.log_skipped(scope:, **extra)
    Rails.logger.warn(
      "PushNotificationService skipped: scope=#{scope} env=#{Rails.env} #{extra.inspect}"
    )
    return unless Sentry.initialized?

    Sentry.add_breadcrumb(
      Sentry::Breadcrumb.new(
        category: 'push_notification',
        level: 'info',
        message: 'PushNotificationService skipped (delivery disabled)',
        data: { scope:, env: Rails.env.to_s, **extra }
      )
    )
  end
  private_class_method :log_skipped
end
