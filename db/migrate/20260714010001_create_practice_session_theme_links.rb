class CreatePracticeSessionThemeLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :practice_session_theme_links do |t|
      t.references :practice_session, null: false, foreign_key: true
      t.references :improvement_theme, null: false, foreign_key: true
      t.timestamps
    end

    add_index :practice_session_theme_links, %i[practice_session_id improvement_theme_id], unique: true,
                                                                                           name: 'index_theme_links_on_session_and_theme'
  end
end
