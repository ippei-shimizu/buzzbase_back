class PushNotificationJob < ApplicationJob
  queue_as :default

  # ユーザー向けプッシュ通知の送信をリクエスト経路から切り離す。
  # Expo Push API クライアント (exponent-server-sdk) はタイムアウト未指定の Typhoeus を
  # 使うため、リクエスト内で同期送信すると相手が詰まったときに Puma スレッドと
  # DB コネクションを無制限に占有し、コネクションプール枯渇を悪化させる。
  #
  # 送信失敗は PushNotificationService 側で rescue して Sentry に記録されるため、
  # このジョブ自体はリトライしない（通知は再送するとユーザーに二重に届く）。
  #
  # @param user_id [Integer] 通知対象ユーザーの id
  # @param title [String] 通知タイトル
  # @param body [String] 通知本文
  def perform(user_id, title:, body:)
    user = User.find_by(id: user_id)
    return unless user

    PushNotificationService.send_to_user(user, title:, body:)
  end
end
