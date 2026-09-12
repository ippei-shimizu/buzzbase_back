class AddPracticeSessionRefToBaseballNotes < ActiveRecord::Migration[7.1]
  def change
    add_reference :baseball_notes, :practice_session, foreign_key: true, null: true
  end
end
