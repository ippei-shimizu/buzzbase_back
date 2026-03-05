class ManagementNotice < ApplicationRecord
  belongs_to :created_by, class_name: 'Admin::User'

  enum status: { draft: 0, published: 1 }

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true
  validates :status, presence: true

  before_save :set_published_at

  scope :published, -> { where(status: :published).order(published_at: :desc) }

  private

  def set_published_at
    self.published_at = Time.current if status_changed? && published?
  end
end
