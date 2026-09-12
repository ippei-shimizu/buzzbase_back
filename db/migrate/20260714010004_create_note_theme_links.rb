class CreateNoteThemeLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :note_theme_links do |t|
      t.references :baseball_note, null: false, foreign_key: true
      t.references :improvement_theme, null: false, foreign_key: true
      t.timestamps
    end

    add_index :note_theme_links, %i[baseball_note_id improvement_theme_id], unique: true,
                                                                            name: 'index_theme_links_on_note_and_theme'
  end
end
