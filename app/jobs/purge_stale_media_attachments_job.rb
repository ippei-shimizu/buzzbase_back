class PurgeStaleMediaAttachmentsJob < ApplicationJob
  queue_as :default

  # presign 後にアプリのクラッシュ・通信断で完了通知が来なかったアップロードは、
  # DB の pending 行と R2 のオブジェクトが残り続ける。無料枠のカウントからは既に
  # 除外しているが、ストレージ費用は増え続けるため定期的に回収する。
  # failed も R2 側にオブジェクトが残っている可能性があるため同じく対象にする。
  #
  # 削除は destroy 経由にして、R2 オブジェクトの削除は既存の after_commit
  # （MediaAttachmentDeletionJob）に委ねる。
  def perform
    MediaAttachment.incomplete_and_stale.find_each(&:destroy)
  end
end
