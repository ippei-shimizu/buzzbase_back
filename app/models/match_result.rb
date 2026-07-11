class MatchResult < ApplicationRecord
  belongs_to :user
  belongs_to :my_team, class_name: 'Team'
  belongs_to :opponent_team, class_name: 'Team'
  belongs_to :tournament, optional: true
  belongs_to :game_result
  belongs_to :stadium, optional: true

  # Rails 7.0 enum は不正値で ArgumentError になるため inclusion バリデーション方式を採用。
  APPEARANCE_TYPES = %w[starter substitute pinch_hitter pinch_runner no_play].freeze

  def appearance_type_starter?
    appearance_type == 'starter'
  end

  validates :game_result_id, uniqueness: true
  validates :date_and_time, presence: true
  validates :match_type, presence: true
  validates :my_team_score, presence: true
  validates :opponent_team_score, presence: true
  validates :defensive_position, presence: true, if: :appearance_type_starter?
  validates :inning_format, presence: true, inclusion: { in: [7, 9] }
  validates :appearance_type, presence: true, inclusion: { in: APPEARANCE_TYPES }

  # 試合の有無は草・Streak の強度に効くため、当日の activity_logs を再計算する。
  after_commit :recalculate_activity, on: %i[create update destroy]

  # 指定ユーザーの試合データに紐づく年度を新しい順で返す
  # @param user [User]
  # @return [Array<Integer>]
  def self.available_years_for(user)
    where(user_id: user.id)
      .pluck(Arel.sql('DISTINCT EXTRACT(YEAR FROM date_and_time)::int'))
      .sort
      .reverse
  end

  private

  # 更新後の日付に加え、date_and_time を変更した場合は変更前の日付も再計算する。
  # 旧日付の activity_log（試合ありの強度）が古いまま残るのを防ぐ。
  def recalculate_activity
    [date_and_time, previous_date_and_time].compact.uniq.each do |time|
      Activities::DailyActivityRecalculator.new(user_id:, date: time.in_time_zone('Asia/Tokyo').to_date).call
    end
  end

  def previous_date_and_time
    return nil unless date_and_time_previously_changed?

    date_and_time_previously_was
  end
end
