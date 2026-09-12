# 投手タイプマスタ（4種: 本格派 / 技巧派 / 変則派 / パワー型）。
class PitcherStyle < ApplicationRecord
  has_many :pitchers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :display_order, presence: true
end
