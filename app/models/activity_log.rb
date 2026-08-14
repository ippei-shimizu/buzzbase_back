class ActivityLog < ApplicationRecord
  belongs_to :user

  validates :activity_date, presence: true
  validates :user_id, uniqueness: { scope: :activity_date }

  scope :in_range, ->(from, to) { where(activity_date: from..to) }
  scope :recent_days, ->(days) { where(activity_date: (Time.find_zone('Asia/Tokyo').today - (days - 1))..) }
end
