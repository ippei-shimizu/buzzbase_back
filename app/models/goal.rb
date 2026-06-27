class Goal < ApplicationRecord
  belongs_to :user
  belongs_to :season, optional: true
  has_many :goal_badges, dependent: :destroy

  PERIOD_TYPES = %w[season monthly].freeze
  COMPARISON_TYPES = %w[greater_than less_than].freeze
  METRIC_KEYS = %w[practice_days total_swing_count game_count batting_average ops era].freeze

  validates :title, presence: true, length: { maximum: 60 }
  validates :period_type, inclusion: { in: PERIOD_TYPES }
  validates :comparison_type, inclusion: { in: COMPARISON_TYPES }
  validates :metric_key, inclusion: { in: METRIC_KEYS }
  validates :target_value, presence: true
  validates :deadline, presence: true

  scope :active, -> { where(is_finalized: false) }
  scope :monthly, -> { where(period_type: 'monthly') }

  JST = 'Asia/Tokyo'.freeze

  # 集計対象の期間（[from, to] の Time 範囲）。
  # 月次は当月、シーズンはそのシーズンの試合の最小〜最大日時。
  # @return [Array(Time, Time), nil]
  def period_range
    if period_type == 'monthly' && month_start
      zone = Time.find_zone(JST)
      start = zone.local(month_start.year, month_start.month, 1)
      [start, start.end_of_month]
    elsif period_type == 'season' && season_id
      games = MatchResult.joins(:game_result).where(game_results: { season_id: })
      min = games.minimum(:date_and_time)
      max = games.maximum(:date_and_time)
      min && max ? [min, max] : nil
    end
  end
end
