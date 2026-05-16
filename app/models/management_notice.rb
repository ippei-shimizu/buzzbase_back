class ManagementNotice < ApplicationRecord
  belongs_to :created_by, class_name: 'Admin::User'

  enum status: { draft: 0, published: 1 }

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true
  validates :status, presence: true

  before_save :set_published_at
  after_commit :enqueue_push_notification_if_needed, on: %i[create update]

  scope :published, -> { where(status: :published).order(published_at: :desc) }

  private

  def set_published_at
    self.published_at = Time.current if status_changed? && published?
  end

  # ステータスが published へ変わったタイミングでのみプッシュ通知ジョブをenqueueする。
  # notified_at が既にセットされている場合は重複送信防止のためスキップする。
  def enqueue_push_notification_if_needed
    return unless saved_change_to_status?(to: ManagementNotice.statuses[:published])
    return if notified_at.present?

    ManagementNoticePushJob.perform_later(id)
  end
end
