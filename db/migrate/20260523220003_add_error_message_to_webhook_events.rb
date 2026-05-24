class AddErrorMessageToWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_events, :error_message, :text
  end
end
