class CreateNoteGameLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :note_game_links do |t|
      t.references :baseball_note, null: false, foreign_key: true
      t.references :game_result, null: false, foreign_key: true
      t.timestamps
    end

    add_index :note_game_links, %i[baseball_note_id game_result_id], unique: true
  end
end
