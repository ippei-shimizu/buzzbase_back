class SeedNoteTagPresets < ActiveRecord::Migration[7.1]
  # マイグレーション時点のスキーマに固定するため、本体モデルではなく専用クラスを使う。
  class MigrationNoteTag < ApplicationRecord
    self.table_name = 'note_tags'
  end

  PRESETS = %w[打撃 守備 走塁 投球 試合 練習].freeze

  def up
    PRESETS.each_with_index do |name, index|
      record = MigrationNoteTag.find_or_initialize_by(name:, is_preset: true, user_id: nil)
      record.update!(sort_order: index)
    end
  end

  def down
    MigrationNoteTag.where(is_preset: true).delete_all
  end
end
