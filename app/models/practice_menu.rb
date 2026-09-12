class PracticeMenu < ApplicationRecord
  belongs_to :user
  has_many :practice_logs, dependent: :nullify

  CATEGORIES = %w[batting pitching defense baserunning training strength care other].freeze
  UNITS = %w[count minutes distance weight_reps].freeze

  validates :name, presence: true, length: { maximum: 50 }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :unit, presence: true, inclusion: { in: UNITS }
  validates :unit_label, length: { maximum: 10 }, allow_nil: true

  scope :active, -> { where(archived: false) }
  # お気に入り先頭・sort_order 昇順でメニュー一覧を並べる
  scope :ordered, -> { order(is_favorite: :desc, sort_order: :asc, created_at: :asc) }
end
