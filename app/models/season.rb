class Season < ApplicationRecord
  belongs_to :user
  has_many :game_results, dependent: :nullify
  # シーズン目標は season_id が外れると集計期間を失うため、進行中のものが残っている間は削除を止める。
  has_many :goals, dependent: :nullify

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :user_id }

  # dependent: :nullify も before_destroy として登録されるため、prepend で必ずガードを先に走らせる。
  before_destroy :guard_against_active_season_goals, prepend: true

  private

  def guard_against_active_season_goals
    return unless goals.exists?(period_type: 'season', is_finalized: false)

    errors.add(:base, '進行中のシーズン目標が紐づいているため削除できません')
    throw(:abort)
  end
end
