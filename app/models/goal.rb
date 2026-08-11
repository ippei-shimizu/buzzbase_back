class Goal < ApplicationRecord
  belongs_to :user
  belongs_to :season, optional: true
  belongs_to :tournament, optional: true
  belongs_to :practice_menu, optional: true
  # 獲得済みバッジは達成の記念として恒久保存する。目標を削除しても道連れにしない。
  has_many :goal_badges, dependent: :nullify

  PERIOD_TYPES = %w[season monthly tournament weekly yearly custom].freeze
  # 個人の期間目標（試合エンティティに紐づかない日付レンジ系）。無料枠を共有する。
  PERSONAL_PERIOD_TYPES = %w[monthly weekly yearly custom].freeze
  # month_start（開始）・deadline（終了）の日付レンジで集計する期間タイプ。
  EXPLICIT_RANGE_TYPES = %w[weekly yearly custom].freeze
  COMPARISON_TYPES = %w[greater_than less_than].freeze
  KINDS = %w[numeric qualitative manual].freeze
  METRIC_KEYS = %w[
    practice_days self_practice_days total_swing_count game_count
    menu_practice_days menu_practice_amount
    batting_average on_base_percentage slugging_percentage ops
    hits home_runs runs_batted_in runs_scored stolen_bases
    era whip strikeouts wins saves
  ].freeze
  # 新規作成では選ばせないが、既存目標の進捗計算・確定を壊さないため METRIC_KEYS には残す。
  DEPRECATED_METRIC_KEYS = %w[total_swing_count].freeze
  SELECTABLE_METRIC_KEYS = (METRIC_KEYS - DEPRECATED_METRIC_KEYS).freeze
  # 対象の練習メニュー指定が必須になる指標。
  MENU_REQUIRED_METRIC_KEYS = %w[menu_practice_days menu_practice_amount].freeze

  validates :title, presence: true, length: { maximum: 60 }
  validates :period_type, inclusion: { in: PERIOD_TYPES }
  validates :kind, inclusion: { in: KINDS }
  validates :comparison_type, inclusion: { in: COMPARISON_TYPES }
  # 数値目標のみ指標必須（定性は達成/未達、自由指標は指標名で管理）。
  validates :metric_key, inclusion: { in: METRIC_KEYS }, if: :numeric?
  # 廃止指標は新規作成のみ禁止する。既存目標は編集も確定もできる状態を保つ。
  validates :metric_key, inclusion: { in: SELECTABLE_METRIC_KEYS }, on: :create, if: :numeric?
  # 数値・自由指標は目標値必須（定性目標のみ不要）。負の目標値は成立しない。
  validates :target_value, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: :qualitative?
  # 自由指標（手動更新）は指標名必須。
  validates :custom_metric_label, presence: true, length: { maximum: 40 }, if: :manual?
  # メニュー単位の指標（継続日数・実施量）は対象メニュー必須。
  validates :practice_menu_id, presence: true, if: -> { MENU_REQUIRED_METRIC_KEYS.include?(metric_key) }
  # 他ユーザーの練習メニューを指定できないようにする（IDOR / 名称漏洩防止）。
  validate :practice_menu_owned_by_user, if: -> { practice_menu_id.present? }
  # 他ユーザーのシーズンを指定できないようにする（IDOR / 集計混入防止）。
  validate :season_owned_by_user, if: -> { season_id.present? }
  validates :deadline, presence: true
  validates :tournament_id, presence: true, if: -> { period_type == 'tournament' }
  # 週次/年間/カスタムは開始日（month_start）必須。開始日 ≤ 期限であること。
  validates :month_start, presence: true, if: -> { EXPLICIT_RANGE_TYPES.include?(period_type) }
  validate :deadline_after_start

  scope :active, -> { where(is_finalized: false) }
  scope :monthly, -> { where(period_type: 'monthly') }

  JST = 'Asia/Tokyo'.freeze

  def numeric?
    kind == 'numeric'
  end

  def qualitative?
    kind == 'qualitative'
  end

  def manual?
    kind == 'manual'
  end

  # 集計対象の期間（[from, to] の Time 範囲）。
  # 月次は当月、週次/年間/カスタムは month_start〜deadline、
  # シーズン/大会はその対象に紐づく試合の最小〜最大日時。
  # @return [Array(Time, Time), nil]
  def period_range
    case period_type
    when 'monthly' then month_range
    when 'weekly', 'yearly', 'custom' then explicit_range
    when 'season'
      return nil unless season_id

      games_range(MatchResult.joins(:game_result).where(game_results: { season_id:, user_id: }))
    when 'tournament'
      return nil unless tournament_id

      games_range(MatchResult.where(tournament_id:, user_id:))
    end
  end

  private

  def month_range
    return nil unless month_start

    zone = Time.find_zone(JST)
    start = zone.local(month_start.year, month_start.month, 1)
    [start, start.end_of_month]
  end

  # month_start（開始日）〜 deadline（終了日）を JST の日境界で範囲にする。
  def explicit_range
    return nil unless month_start && deadline

    zone = Time.find_zone(JST)
    from = zone.local(month_start.year, month_start.month, month_start.day)
    to = zone.local(deadline.year, deadline.month, deadline.day).end_of_day
    [from, to]
  end

  def deadline_after_start
    return if month_start.blank? || deadline.blank? || deadline >= month_start

    errors.add(:deadline, 'は開始日以降にしてください')
  end

  def practice_menu_owned_by_user
    return if practice_menu&.user_id == user_id

    errors.add(:practice_menu_id, 'は自分の練習メニューを指定してください')
  end

  def season_owned_by_user
    return if season&.user_id == user_id

    errors.add(:season_id, 'は自分のシーズンを指定してください')
  end

  def games_range(games)
    min = games.minimum(:date_and_time)
    max = games.maximum(:date_and_time)
    min && max ? [min, max] : nil
  end
end
