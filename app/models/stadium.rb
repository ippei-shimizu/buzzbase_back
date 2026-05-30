class Stadium < ApplicationRecord
  belongs_to :prefecture, optional: true
  belongs_to :created_by_user, class_name: 'User', optional: true
  has_many :match_results, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
end
