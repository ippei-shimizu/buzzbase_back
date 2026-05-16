class ManagementNoticePushJob < ApplicationJob
  queue_as :default

  # お知らせ公開時に、全ユーザーの端末へプッシュ通知を一斉送信する。
  # 冪等性ガード: notified_at が既にセットされている場合はスキップする。
  # 完了後は update_column で notified_at を更新し、ManagementNotice の
  # after_commit コールバックを再発火させない（無限ループ防止）。
  #
  # 失敗時のリカバリ:
  #   :async アダプタは自動リトライしないため、PushNotificationService.send_to_all が
  #   raise した場合は notified_at が nil のまま残り、ジョブは失敗で終了する。
  #   ステータスは published のままで after_commit は再発火しないため、自動再送はされない。
  #   Sentry アラートを受けたら、管理者は Rails コンソールから手動で再送する:
  #     ManagementNoticePushJob.perform_later(<notice_id>)
  #
  # @param notice_id [Integer] ManagementNotice の id
  def perform(notice_id)
    notice = ManagementNotice.find_by(id: notice_id)
    unless notice
      Rails.logger.warn("ManagementNoticePushJob: notice not found (id=#{notice_id})")
      return
    end

    return if notice.notified_at.present?

    PushNotificationService.send_to_all(
      title: 'BUZZ BASE お知らせ',
      body: notice.title
    )

    # NOTE: ManagementNotice の after_commit コールバックの再発火を防ぐため、
    # 意図的に update_column を使用してコールバックをスキップする。
    notice.update_column(:notified_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
