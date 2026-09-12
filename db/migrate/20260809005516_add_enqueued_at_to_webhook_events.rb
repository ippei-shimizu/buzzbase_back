class AddEnqueuedAtToWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_events, :enqueued_at, :datetime
  end
end
