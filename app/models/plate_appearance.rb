class PlateAppearance < ApplicationRecord
  belongs_to :game_result
  belongs_to :user
  belongs_to :plate_result, optional: true
  belongs_to :contact_quality, optional: true
  belongs_to :timing, optional: true
  belongs_to :pitch_type, optional: true
  belongs_to :pitcher, optional: true
  belongs_to :appearance_situation, optional: true

  # Rails 7.1 では enum がカラム未存在状態だと "Undeclared attribute type" エラーになるため、
  # 明示的に attribute type を declare してマイグレーション前後どちらでもロードできるようにする。
  attribute :out_type, :integer
  attribute :hit_type, :integer
  attribute :runners_state, :integer

  enum out_type: { ground_ball: 0, fly_ball: 1, line_drive: 2, double_play: 3, foul_fly: 4 }, _prefix: true
  enum hit_type: { single: 0, double: 1, triple: 2, home_run: 3 }, _prefix: true
  enum runners_state: {
    no_runner: 0,
    first: 1,
    second: 2,
    third: 3,
    first_second: 4,
    first_third: 5,
    second_third: 6,
    bases_loaded: 7
  }, _prefix: true

  # 打球位置は正規化座標 (0.0〜1.0) で保存する。
  # DB の precision: 4, scale: 3 は範囲外値を許してしまうため、モデル側で防ぐ。
  validates :hit_location_x, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :hit_location_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
end
