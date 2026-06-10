# 相手投手マスタ。ユーザー追加可能（球場マスタと同パターン）だが、
# `created_by_user_id` 経由で **記録したユーザーのみが閲覧・紐付け可能** な
# ユーザー固有マスタとして扱う（球場のように全体共有はしない）。
#
# 同じ投手と複数回対戦する想定のため、属性を毎回入力させず再利用する。
class Pitcher < ApplicationRecord
  belongs_to :team, optional: true
  belongs_to :arm_angle, optional: true
  belongs_to :velocity_zone, optional: true
  belongs_to :pitcher_style, optional: true
  belongs_to :created_by_user, class_name: 'User'

  has_many :plate_appearances, dependent: :nullify

  enum throw_hand: { right: 0, left: 1 }, _prefix: true

  validates :name, presence: true, length: { maximum: 100 }
  # 同一ユーザー内 + 同一チームでの同名投手を防ぐ。team_id が異なれば別投手扱い。
  # `index_pitchers_on_user_team_name` (unique, created_by_user_id + team_id + name) が
  # スコープを丸ごとカバーするが、RuboCop は単独カラムの index しか検出できないため抑制する。
  validates :name, uniqueness: { scope: %i[created_by_user_id team_id], case_sensitive: false }
end
