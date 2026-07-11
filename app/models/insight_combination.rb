class InsightCombination < ApplicationRecord
  belongs_to :user
  belongs_to :practice_menu, optional: true

  validates :input_type, inclusion: { in: Insights::Catalog::INPUT_TYPES }
  validates :metric, inclusion: { in: Insights::Catalog::METRIC_KEYS }
  validates :practice_menu_id, presence: true, if: -> { input_type == 'practice_menu' }
  # 他ユーザーのメニューを入力に指定できないようにする（IDOR 防止）。
  validate :practice_menu_owned_by_user, if: -> { practice_menu_id.present? }

  scope :ordered, -> { order(sort_order: :asc, id: :asc) }

  private

  def practice_menu_owned_by_user
    return if practice_menu&.user_id == user_id

    errors.add(:practice_menu_id, 'は自分の練習メニューを指定してください')
  end
end
