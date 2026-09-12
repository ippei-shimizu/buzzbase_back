# 投手の登板状況マスタ（3種: 先発 / 中継ぎ / 抑え）。
# 試合終盤の対投手成績分析に使う。
class AppearanceSituation < ApplicationRecord
  has_many :plate_appearances, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :display_order, presence: true
end
