class AddLinksToBaseballNotes < ActiveRecord::Migration[7.1]
  def change
    add_reference :baseball_notes, :game_result, null: true, foreign_key: { on_delete: :nullify }
    add_reference :baseball_notes, :practice_log, null: true, foreign_key: { on_delete: :nullify }
  end
end
