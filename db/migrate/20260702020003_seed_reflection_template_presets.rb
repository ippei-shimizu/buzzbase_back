class SeedReflectionTemplatePresets < ActiveRecord::Migration[7.1]
  # マイグレーション時点のスキーマに固定するため、本体モデルではなく専用クラスを使う。
  class MigrationReflectionTemplate < ApplicationRecord
    self.table_name = 'reflection_templates'
  end

  PRESETS = [
    { title: 'ふりかえり3行', questions: %w[うまくいったこと 課題 次やること] },
    { title: '課題フォーカス', questions: ['今日の課題への手応え（◎○△）', '気づき', '次に試すこと'] },
    { title: '試合後', questions: ['良かった打席・投球', '悔しかった場面', '次戦への修正点'] },
    { title: 'コンディション重視', questions: %w[体の状態 疲れの原因 ケアすること] }
  ].freeze

  def up
    PRESETS.each_with_index do |preset, index|
      record = MigrationReflectionTemplate.find_or_initialize_by(title: preset[:title], is_preset: true, user_id: nil)
      record.update!(questions: preset[:questions], sort_order: index)
    end
  end

  def down
    MigrationReflectionTemplate.where(is_preset: true).delete_all
  end
end
