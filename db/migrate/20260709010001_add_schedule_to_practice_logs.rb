class AddScheduleToPracticeLogs < ActiveRecord::Migration[7.1]
  def change
    add_reference :practice_logs, :schedule, null: true, foreign_key: true
  end
end
