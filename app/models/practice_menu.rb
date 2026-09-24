class PracticeMenu < ApplicationRecord
  belongs_to :user
  has_many :practice_logs, dependent: :nullify

  CATEGORIES = %w[batting pitching defense baserunning training strength care other].freeze
  UNITS = %w[count minutes distance weight_reps].freeze

  # 素振りカウンターが自動生成するメニュー。同条件の部分ユニークインデックスが
  # 張られているため、バリデーションで先に弾かないと 500/409 になる。
  SHADOW_SWING_NAME = '素振り'.freeze
  SHADOW_SWING_UNIT = 'count'.freeze

  validates :name, presence: true, length: { maximum: 50 }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :unit, presence: true, inclusion: { in: UNITS }
  validates :unit_label, length: { maximum: 10 }, allow_nil: true
  validate :shadow_swing_menu_not_duplicated

  scope :active, -> { where(archived: false) }
  # お気に入り先頭・sort_order 昇順でメニュー一覧を並べる
  scope :ordered, -> { order(is_favorite: :desc, sort_order: :asc, created_at: :asc) }

  private

  # 素振りメニューだけは自動生成と衝突するため重複を許さない。
  # archived は一覧にも紐付け対象にも出てこないので重複扱いしない。
  def shadow_swing_menu_not_duplicated
    return if archived?
    return unless name == SHADOW_SWING_NAME && unit == SHADOW_SWING_UNIT
    return if user_id.blank?

    duplicates = PracticeMenu.active.where(user_id:, name: SHADOW_SWING_NAME, unit: SHADOW_SWING_UNIT)
    duplicates = duplicates.where.not(id:) if persisted?
    return unless duplicates.exists?

    errors.add(:base, "「#{SHADOW_SWING_NAME}」のメニューは既に登録されています")
  end
end
