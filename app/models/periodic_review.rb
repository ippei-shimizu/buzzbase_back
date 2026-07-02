class PeriodicReview < ApplicationRecord
  belongs_to :user

  # summary 内で Pro 限定として出し分ける詳細キー（課題別内訳・コンディション・成績前週比・相関）。
  ADVANCED_SUMMARY_KEYS = %w[theme_breakdown condition batting insight].freeze

  enum period_type: { weekly: 'weekly', monthly: 'monthly' }

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :period_type, uniqueness: { scope: %i[user_id period_start] }

  scope :recent_first, -> { order(period_start: :desc) }
  scope :unread, -> { where(read: false) }
end
