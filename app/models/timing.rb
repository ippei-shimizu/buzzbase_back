class Timing < ApplicationRecord
  has_many :plate_appearances, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :display_order, presence: true
end
