class AddMemoToMediaAttachments < ActiveRecord::Migration[7.1]
  def change
    add_column :media_attachments, :memo, :text
  end
end
