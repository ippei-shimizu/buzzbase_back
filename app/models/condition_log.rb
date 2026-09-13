class ConditionLog < ApplicationRecord
  belongs_to :user

  LEVEL_RANGE = (1..4)

  # 無料プランでも記録できる項目（condition_log_basic）。
  # これ以外（sleep_hours / mood / memo / injuries）は Pro 限定（detailed_condition_log）。
  # 許可リスト方式にすることで、新しく列を足したとき既定で Pro 側に寄る。
  BASIC_ATTRIBUTES = %i[fatigue_level physical_level].freeze

  validates :logged_on, presence: true
  validates :user_id, uniqueness: { scope: :logged_on }
  validates :fatigue_level, inclusion: { in: LEVEL_RANGE }, allow_nil: true
  validates :physical_level, inclusion: { in: LEVEL_RANGE }, allow_nil: true
  validates :sleep_hours, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }, allow_nil: true

  # コンディションログは草・Streak に影響させない（休養日でも記録するため）。
  # よって activity_logs の再計算フックは持たない。
end
