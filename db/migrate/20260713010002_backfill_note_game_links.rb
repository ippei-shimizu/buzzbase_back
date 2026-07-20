class BackfillNoteGameLinks < ActiveRecord::Migration[7.1]
  # マイグレーション内では将来カラム削除・型変更されるアプリのモデルに依存しないよう、
  # このマイグレーション実行時点のテーブル構造だけを見る匿名モデルを使う。
  # rubocop:disable Rails/ApplicationRecord
  class MigrationBaseballNote < ActiveRecord::Base
    self.table_name = 'baseball_notes'
  end

  class MigrationNoteGameLink < ActiveRecord::Base
    self.table_name = 'note_game_links'
  end
  # rubocop:enable Rails/ApplicationRecord

  def up
    MigrationBaseballNote.where.not(game_result_id: nil).find_each do |note|
      MigrationNoteGameLink.find_or_create_by!(baseball_note_id: note.id, game_result_id: note.game_result_id)
    end
  end

  def down
    # note_game_links から baseball_notes.game_result_id への書き戻しは、複数紐付けがある場合に
    # 非可逆（1件しか書き戻せない）ため何もしない。ロールバックは本マイグレーションの前段で止める運用とする。
  end
end
