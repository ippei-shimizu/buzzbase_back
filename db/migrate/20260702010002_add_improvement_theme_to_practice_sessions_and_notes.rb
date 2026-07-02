class AddImprovementThemeToPracticeSessionsAndNotes < ActiveRecord::Migration[7.1]
  def change
    add_reference :practice_sessions, :improvement_theme, null: true, foreign_key: true
    add_reference :baseball_notes, :improvement_theme, null: true, foreign_key: true
  end
end
