class GroupRankingSnapshot < ApplicationRecord
  belongs_to :group
  belongs_to :user

  BATTING_STAT_TYPES = %w[
    batting_average
    home_run
    runs_batted_in
    hit
    stealing_base
    on_base_percentage
  ].freeze

  PITCHING_STAT_TYPES = %w[
    era
    win
    saves
    hold
    strikeouts
    win_percentage
  ].freeze

  ALL_STAT_TYPES = (BATTING_STAT_TYPES + PITCHING_STAT_TYPES).freeze

  validates :stat_type, inclusion: { in: ALL_STAT_TYPES }
  validates :rank, numericality: { greater_than: 0 }
  validates :snapshot_date, presence: true

  scope :for_group, ->(group_id) { where(group_id: group_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_date, ->(date) { where(snapshot_date: date) }

  def self.latest_for(group_id:, user_id:, stat_type:)
    where(group_id: group_id, user_id: user_id, stat_type: stat_type)
      .order(snapshot_date: :desc)
      .first
  end
end
