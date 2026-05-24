class AddStripeColumnsToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :subscriptions, :stripe_customer_id, :string
    add_column :subscriptions, :stripe_subscription_id, :string

    # 値があるレコードだけ一意性を担保したい（多くのユーザーは Stripe を使わないため nil 重複が大量に発生する）。
    add_index :subscriptions, :stripe_customer_id,
              unique: true,
              where: 'stripe_customer_id IS NOT NULL'
    add_index :subscriptions, :stripe_subscription_id,
              unique: true,
              where: 'stripe_subscription_id IS NOT NULL'
  end
end
