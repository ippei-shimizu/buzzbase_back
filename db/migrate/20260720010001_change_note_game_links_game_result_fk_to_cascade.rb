class ChangeNoteGameLinksGameResultFkToCascade < ActiveRecord::Migration[7.1]
  # game_results.match_result_id が ON DELETE CASCADE のため、has_one match_result の
  # dependent: :destroy で match_result を消すと DB カスケードで game_results 行が先に消える。
  # このとき note_game_links.game_result_id が NO ACTION だと FK 違反で試合削除が失敗するため、
  # 中間リンク側も ON DELETE CASCADE にして親削除に追随させる。
  def up
    remove_foreign_key :note_game_links, :game_results
    add_foreign_key :note_game_links, :game_results, on_delete: :cascade
  end

  def down
    remove_foreign_key :note_game_links, :game_results
    add_foreign_key :note_game_links, :game_results
  end
end
