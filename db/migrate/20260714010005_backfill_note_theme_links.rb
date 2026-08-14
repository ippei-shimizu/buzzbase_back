class BackfillNoteThemeLinks < ActiveRecord::Migration[7.1]
  # rubocop:disable Rails/ApplicationRecord
  class MigrationBaseballNote < ActiveRecord::Base
    self.table_name = 'baseball_notes'
  end

  class MigrationNoteThemeLink < ActiveRecord::Base
    self.table_name = 'note_theme_links'
  end
  # rubocop:enable Rails/ApplicationRecord

  def up
    MigrationBaseballNote.where.not(improvement_theme_id: nil).find_each do |note|
      MigrationNoteThemeLink.find_or_create_by!(
        baseball_note_id: note.id, improvement_theme_id: note.improvement_theme_id
      )
    end
  end

  def down
    # 複数紐付けがある場合、単一カラムへの書き戻しは情報損失があるため何もしない。
    # ロールバックは本マイグレーションの前段で止める運用とする。
  end
end
