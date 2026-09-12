class CreateUserSubscriptionEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :user_subscription_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :subscription, null: true, foreign_key: true
      t.string :event_type, null: false
      t.string :platform
      t.string :product_id
      t.string :period_type
      t.datetime :occurred_at, null: false
      t.jsonb :raw_payload
      t.string :revenuecat_event_id
      t.timestamps
    end

    add_index :user_subscription_events, :revenuecat_event_id, unique: true
    add_index :user_subscription_events, %i[user_id occurred_at]
    add_index :user_subscription_events, :event_type
  end
end
