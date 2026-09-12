class MenuSet < ApplicationRecord
  belongs_to :user
  has_many :menu_set_items, -> { order(:sort_order) }, dependent: :destroy, inverse_of: :menu_set
  has_many :practice_menus, through: :menu_set_items
  has_many :schedules, dependent: :nullify

  validates :name, presence: true, length: { maximum: 50 }

  scope :ordered, -> { order(:sort_order, :created_at) }
end
