class NoteTag < ApplicationRecord
  # user_id が nil のものは運営提供プリセット。ユーザー自作は user に属する。
  belongs_to :user, optional: true
  has_many :note_taggings, dependent: :destroy
  has_many :baseball_notes, through: :note_taggings

  validates :name, presence: true, length: { maximum: 20 }
  validates :name, uniqueness: { scope: :user_id }

  scope :presets, -> { where(is_preset: true, user_id: nil) }
  scope :ordered, -> { order(sort_order: :asc, id: :asc) }

  # ユーザーが利用できるタグ（本人の自作 ＋ 運営プリセット）。
  # @param user [User]
  # @return [ActiveRecord::Relation]
  def self.available_for(user)
    where(user_id: user.id).or(presets)
  end
end
