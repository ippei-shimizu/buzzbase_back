class Goal < ApplicationRecord
  belongs_to :user
  belongs_to :season, optional: true
  belongs_to :tournament, optional: true
  has_many :goal_badges, dependent: :destroy

  PERIOD_TYPES = %w[season monthly tournament].freeze
  COMPARISON_TYPES = %w[greater_than less_than].freeze
  METRIC_KEYS = %w[practice_days total_swing_count game_count batting_average ops era].freeze

  validates :title, presence: true, length: { maximum: 60 }
  validates :period_type, inclusion: { in: PERIOD_TYPES }
  validates :comparison_type, inclusion: { in: COMPARISON_TYPES }
  validates :metric_key, inclusion: { in: METRIC_KEYS }
  validates :target_value, presence: true
  validates :deadline, presence: true
  validates :tournament_id, presence: true, if: -> { period_type == 'tournament' }

  scope :active, -> { where(is_finalized: false) }
  scope :monthly, -> { where(period_type: 'monthly') }

  JST = 'Asia/Tokyo'.freeze

  # 集計対象の期間（[from, to] の Time 範囲）。
  # 月次は当月、シーズン/大会はその対象に紐づく試合の最小〜最大日時。
  # @return [Array(Time, Time), nil]
  def period_range
    case period_type
    when 'monthly'
      return nil unless month_start

      zone = Time.find_zone(JST)
      start = zone.local(month_start.year, month_start.month, 1)
      [start, start.end_of_month]
    when 'season'
      return nil unless season_id

      games_range(MatchResult.joins(:game_result).where(game_results: { season_id: }))
    when 'tournament'
      return nil unless tournament_id

      games_range(MatchResult.where(tournament_id:, user_id:))
    end
  end

  private

  def games_range(games)
    min = games.minimum(:date_and_time)
    max = games.maximum(:date_and_time)
    min && max ? [min, max] : nil
  end
end
