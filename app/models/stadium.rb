class Stadium < ApplicationRecord
  belongs_to :prefecture, optional: true
  belongs_to :created_by_user, class_name: 'User', optional: true
  has_many :match_results, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  # 同一都道府県内での同名球場を防ぐ。prefecture_id が NULL の場合は重複を許容する（県不明データ向け）。
  validates :name, uniqueness: { scope: :prefecture_id, case_sensitive: false }, if: -> { prefecture_id.present? }
end
