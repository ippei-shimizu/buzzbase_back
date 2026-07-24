class Season < ApplicationRecord
  belongs_to :user
  has_many :game_results, dependent: :nullify

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :user_id }
end
