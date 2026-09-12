class DropCancellationFeedbacks < ActiveRecord::Migration[7.1]
  # 解約アンケート機能の削除に伴いテーブルを drop する。
  # 本番はフラグ OFF のままリリースされていないためレコードは 0 件想定（drop 前に本番件数を確認すること）。
  def up
    drop_table :cancellation_feedbacks, if_exists: true
  end

  def down
    create_table :cancellation_feedbacks do |t|
      t.bigint :user_id, null: false
      t.bigint :subscription_id
      t.string :reason, null: false
      t.text :note
      t.timestamps
      t.index :subscription_id
      t.index :user_id
    end
    add_foreign_key :cancellation_feedbacks, :users
    add_foreign_key :cancellation_feedbacks, :subscriptions, on_delete: :nullify
  end
end
