class BackfillDefaultSubscriptionsForExistingUsers < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL.squish
      INSERT INTO subscriptions (user_id, status, has_used_trial, is_early_subscriber, revenuecat_entitlement_id, created_at, updated_at)
      SELECT id, 'free', FALSE, FALSE, 'pro', NOW(), NOW()
      FROM users
      WHERE id NOT IN (SELECT user_id FROM subscriptions);
    SQL
  end

  def down
    execute "DELETE FROM subscriptions WHERE status = 'free';"
  end
end
