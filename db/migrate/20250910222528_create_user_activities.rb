class CreateUserActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity_type, null: false
      t.text :activity_data
      t.string :ip_address
      t.text :user_agent
      t.datetime :occurred_at, null: false

      t.timestamps null: false
    end
    
    add_index :user_activities, :activity_type
    add_index :user_activities, :occurred_at
    add_index :user_activities, [:user_id, :occurred_at]
    add_index :user_activities, [:activity_type, :occurred_at]
  end
end
