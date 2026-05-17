class CreateWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_events do |t|
      t.string :provider, null: false
      t.string :external_event_id, null: false
      t.string :event_type
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.string :status, null: false, default: 'pending'
      t.jsonb :payload
      t.timestamps
    end

    add_index :webhook_events, %i[provider external_event_id], unique: true
    add_index :webhook_events, :status
  end
end
