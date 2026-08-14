class AddMediaAttachmentsCountToBaseballNotes < ActiveRecord::Migration[7.1]
  def change
    add_column :baseball_notes, :media_attachments_count, :integer, null: false, default: 0
  end
end
