class PlateAppearance < ApplicationRecord
  # plate_results マスタの「三振」エントリの ID。swing_type は三振のときのみ
  # 意味を持つので、validate でこの ID とセットで指定されているか確認する。
  STRIKEOUT_RESULT_ID = 13

  # 投球コース（打席結果が決まった最後の1球）。捕手目線・行優先の 5x5 グリッド
  # （左上=1 〜 右下=25、row = (n-1)/5 + 1、col = (n-1)%5 + 1）。
  # 保存値は打者の左右でミラーせず常に捕手目線の絶対座標で固定する。
  # 内角/外角のラベルは表示側で users.batting_side から導出する。
  PITCH_COURSES = (1..25).to_a.freeze
  # 中央 3x3 がストライクゾーン、外周 16 マスがボールゾーン。
  STRIKE_ZONE_COURSES = [7, 8, 9, 12, 13, 14, 17, 18, 19].freeze

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
  attribute :swing_type, :integer

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
  enum swing_type: { swinging: 0, looking: 1 }, _prefix: true

  # 打球位置は正規化座標 (0.0〜1.0) で保存する。
  # DB の precision: 4, scale: 3 は範囲外値を許してしまうため、モデル側で防ぐ。
  validates :hit_location_x, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :hit_location_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  # hit_directions マスタ撤廃に伴い AR レベルの参照整合性チェックが無くなったため、
  # DIRECTION_LABELS (1〜13) を SSoT として inclusion で範囲を保証する。
  validates :hit_direction_id,
            inclusion: { in: ::Stats::HitDirectionAggregator::DIRECTION_LABELS.keys },
            allow_nil: true

  # コースはマスタテーブルを持たず（幾何的定義で運用変更の余地がない）、
  # hit_direction_id と同じ流儀で定数 + inclusion で範囲を保証する。
  validates :pitch_course, inclusion: { in: PITCH_COURSES }, allow_nil: true

  validate :swing_type_only_for_strikeout

  private

  def swing_type_only_for_strikeout
    return if swing_type.blank?
    return if plate_result_id == STRIKEOUT_RESULT_ID

    errors.add(:swing_type, 'は三振 (plate_result_id=13) のときのみ指定可能です')
  end
end
