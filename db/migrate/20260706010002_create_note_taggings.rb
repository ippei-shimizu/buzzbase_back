class CreateNoteTaggings < ActiveRecord::Migration[7.1]
  def change
    create_table :note_taggings do |t|
      t.references :baseball_note, null: false, foreign_key: true
      t.references :note_tag, null: false, foreign_key: true
      t.timestamps
    end

    add_index :note_taggings, %i[baseball_note_id note_tag_id], unique: true
  end
end
