class CreatePracticeSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :practice_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.text :memo

      t.timestamps
    end

    add_index :practice_sessions, %i[user_id logged_on], unique: true
  end
end
