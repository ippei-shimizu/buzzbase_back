class RemoveImprovementThemeIdFromPracticeSessions < ActiveRecord::Migration[7.1]
  def change
    remove_reference :practice_sessions, :improvement_theme, foreign_key: true, index: true
  end
end
