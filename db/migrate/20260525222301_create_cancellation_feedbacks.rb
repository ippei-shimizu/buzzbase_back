class CreateCancellationFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :cancellation_feedbacks do |t|
      t.references :user, null: false, foreign_key: true
      # subscription が消えても feedback は保持したいので nullable + on_delete: :nullify。
      t.references :subscription, foreign_key: { on_delete: :nullify }
      t.string :reason, null: false
      t.text :note
      t.timestamps
    end
  end
end
