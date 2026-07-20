class CreateMediaAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :media_attachments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :baseball_note, null: false, foreign_key: true
      t.string :media_type, null: false
      t.string :r2_key, null: false
      t.string :thumbnail_r2_key
      t.integer :file_size_bytes
      t.integer :duration_seconds
      t.integer :width
      t.integer :height
      t.integer :position, null: false, default: 0
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end

    add_index :media_attachments, %i[user_id created_at]
  end
end
