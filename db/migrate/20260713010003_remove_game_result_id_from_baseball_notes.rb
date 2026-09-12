class RemoveGameResultIdFromBaseballNotes < ActiveRecord::Migration[7.1]
  def change
    remove_reference :baseball_notes, :game_result, foreign_key: { on_delete: :nullify }, index: true
  end
end
