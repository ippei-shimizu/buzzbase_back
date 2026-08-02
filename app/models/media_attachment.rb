class MediaAttachment < ApplicationRecord
  belongs_to :user
  belongs_to :baseball_note, counter_cache: true, inverse_of: :media_attachments

  MEDIA_TYPES = %w[image video].freeze
  STATUSES = %w[pending ready failed].freeze
  # 完了しなかったアップロードを回収するまでの猶予。署名URLの有効期限（10分）に対して
  # 十分長く取り、極端に遅い回線のアップロード中に消してしまわないようにする。
  INCOMPLETE_RETENTION = 24.hours

  # 完了通知が来ないまま放置され、R2 オブジェクトだけが残っている可能性のあるレコード。
  scope :incomplete_and_stale, lambda {
    where(status: %w[pending failed]).where(created_at: ...INCOMPLETE_RETENTION.ago)
  }

  validates :media_type, inclusion: { in: MEDIA_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :r2_key, presence: true

  scope :ordered, -> { order(:position, :id) }

  after_commit :enqueue_r2_deletion, on: :destroy

  def video?
    media_type == 'video'
  end

  private

  # R2への外部API呼び出しはリクエストの応答時間に含めないため非同期化する。
  def enqueue_r2_deletion
    MediaAttachmentDeletionJob.perform_later(r2_key, thumbnail_r2_key)
  end
end
