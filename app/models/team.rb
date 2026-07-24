class Team < ApplicationRecord
  belongs_to :category, class_name: 'BaseballCategory', optional: true
  belongs_to :prefecture, optional: true
  has_one :user, foreign_key: 'user_id', primary_key: 'id', dependent: :destroy, inverse_of: :team

  before_validation :strip_name

  validates :name, presence: true
  validates :category_id, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :prefecture_id, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :prefecture_must_exist
  validate :category_must_exist

  private

  # クライアント側のバリデーションが truthy チェックのみで空白のみの文字列を許容してしまうため、
  # presence バリデーションの前提を満たすようサーバー側で trim する。
  def strip_name
    self.name = name.strip if name.is_a?(String)
  end

  # prefecture_id がマスターに存在することを保証する。
  # numericality バリデーションを通り抜けた正の整数でも、prefectures テーブルに該当行が
  # 存在しなければ FK 違反 (PG::ForeignKeyViolation) になり 500 を返してしまうため、
  # ActiveRecord 層で先に検出する。
  def prefecture_must_exist
    return if prefecture_id.blank?
    return if errors[:prefecture_id].any?
    return if Prefecture.exists?(id: prefecture_id)

    errors.add(:prefecture_id, 'は存在しない都道府県です')
  end

  # category_id がマスターに存在することを保証する。詳細は prefecture_must_exist と同様。
  def category_must_exist
    return if category_id.blank?
    return if errors[:category_id].any?
    return if BaseballCategory.exists?(id: category_id)

    errors.add(:category_id, 'は存在しないカテゴリです')
  end
end
