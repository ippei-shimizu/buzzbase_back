# 投手の球速帯マスタ（5種）。display_order で UI 表示順を保持する。
class VelocityZone < ApplicationRecord
  has_many :pitchers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :display_order, presence: true
end
