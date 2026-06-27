class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: 'free'
      t.string :plan_type
      t.string :platform
      t.string :product_id
      t.datetime :started_at
      t.datetime :expires_at
      t.datetime :cancelled_at
      t.datetime :refunded_at
      t.datetime :billing_issue_at
      t.boolean :has_used_trial, null: false, default: false
      t.string :revenuecat_user_id
      # RevenueCat 側で割り当てられた entitlement の ID。Pro 加入時のみ値が入り、
      # 無料ユーザーは NULL のままにする（'pro' 等のデフォルトを置くと
      # RevenueCat 連携時に「pro entitlement 保有」と誤判定される）
      t.string :revenuecat_entitlement_id
      t.boolean :is_early_subscriber, null: false, default: false
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, :expires_at
    add_index :subscriptions, :revenuecat_user_id, unique: true
  end
end
