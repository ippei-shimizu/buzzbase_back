class MatchResult < ApplicationRecord
  belongs_to :user
  belongs_to :my_team, class_name: 'Team'
  belongs_to :opponent_team, class_name: 'Team'
  belongs_to :tournament, optional: true
  belongs_to :game_result

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
  validates :batting_order, presence: true, if: :appearance_type_starter?
  validates :defensive_position, presence: true, if: :appearance_type_starter?
  validates :inning_format, presence: true, inclusion: { in: [7, 9] }
  validates :appearance_type, presence: true, inclusion: { in: APPEARANCE_TYPES }

  # 指定ユーザーの試合データに紐づく年度を新しい順で返す
  # @param user [User]
  # @return [Array<Integer>]
  def self.available_years_for(user)
    where(user_id: user.id)
      .pluck(Arel.sql('DISTINCT EXTRACT(YEAR FROM date_and_time)::int'))
      .sort
      .reverse
  end
end
