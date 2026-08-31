class ApprovePendingFollowRequestsJob < ApplicationJob
  queue_as :default

  # 失敗をそのまま捨てると承認待ちが永久に pending のまま残るため、指数バックオフでリトライする。
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # 非公開→公開へ切り替えたユーザーの承認待ちフォローリクエストを一括承認する。
  # 承認待ちが多いユーザーのプロフィール更新リクエストを遅くしないよう非同期で行う。
  #
  # @param user_id [Integer] 公開に切り替えたユーザーの id
  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user
    # ジョブ実行前に非公開へ戻していた場合は、承認待ちをそのまま残す。
    return if user.is_private?

    user.approve_all_pending_requests!
  end
end
