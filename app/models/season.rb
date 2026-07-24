class Season < ApplicationRecord
  belongs_to :user
  has_many :game_results, dependent: :nullify

  before_validation :strip_name

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :user_id }

  private

  # クライアント側のバリデーションが truthy チェックのみで空白のみの文字列を許容してしまうため、
  # presence / uniqueness バリデーションの前提を満たすようサーバー側で trim する。
  def strip_name
    self.name = name.strip if name.is_a?(String)
  end
end
