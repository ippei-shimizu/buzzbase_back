class DropUserActivities < ActiveRecord::Migration[7.0]
  def change
    drop_table :user_activities do |t|
      t.bigint :user_id, null: false
      t.string :activity_type, null: false
      t.text :activity_data
      t.string :ip_address
      t.text :user_agent
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [:user_id]
      t.index [:activity_type]
      t.index [:occurred_at]
      t.index [:user_id, :occurred_at]
    end
  end
end
