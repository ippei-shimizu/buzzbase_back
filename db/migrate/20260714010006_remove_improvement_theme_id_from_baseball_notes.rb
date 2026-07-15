class RemoveImprovementThemeIdFromBaseballNotes < ActiveRecord::Migration[7.1]
  def change
    remove_reference :baseball_notes, :improvement_theme, foreign_key: true, index: true
  end
end
