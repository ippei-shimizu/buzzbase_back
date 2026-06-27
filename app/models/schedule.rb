class Schedule < ApplicationRecord
  belongs_to :user
  has_many :schedule_menus, -> { order(:sort_order) }, dependent: :destroy, inverse_of: :schedule
  has_many :practice_menus, through: :schedule_menus

  validates :title, presence: true, length: { maximum: 50 }
  validates :days_of_week, presence: true
  validates :scheduled_time, presence: true

  scope :active, -> { where(active: true) }

  # "1,3,5" を整数配列に変換する。
  # @return [Array<Integer>]
  def day_numbers
    days_of_week.to_s.split(',').map(&:to_i)
  end
end
