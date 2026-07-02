class ReflectionTemplate < ApplicationRecord
  # user_id が nil のものは運営提供プリセット。ユーザー自作は user に属する。
  belongs_to :user, optional: true

  validates :title, presence: true, length: { maximum: 50 }
  validate :questions_must_be_array_of_strings

  scope :presets, -> { where(is_preset: true) }
  scope :ordered, -> { order(sort_order: :asc, created_at: :asc) }

  after_save :unset_other_defaults, if: -> { is_default? && user_id.present? && saved_change_to_is_default? }

  # プリセット＋指定ユーザーの自作テンプレを返す。
  # @param user [User]
  # @return [ActiveRecord::Relation]
  def self.available_for(user)
    where(is_preset: true).or(where(user_id: user.id)).ordered
  end

  private

  # 同一ユーザーの既定テンプレは1つに保つ。
  def unset_other_defaults
    ReflectionTemplate.where(user_id:, is_default: true).where.not(id:).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
  end

  def questions_must_be_array_of_strings
    return if questions.is_a?(Array) && questions.all?(String)

    errors.add(:questions, 'は文字列の配列である必要があります')
  end
end
