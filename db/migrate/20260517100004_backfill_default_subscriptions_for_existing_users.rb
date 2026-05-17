class BackfillDefaultSubscriptionsForExistingUsers < ActiveRecord::Migration[7.0]
  # Pro 機能リリース前から存在する既存ユーザーには User#after_create が遡及しないため、
  # 全ユーザーに status = 'free' の subscription を1件ずつ作る。
  # 以降のコードは「全ユーザーが必ず subscription を持つ」前提で書ける。
  # revenuecat_entitlement_id は無料ユーザーには NULL で残す（Pro 加入時に入る）。
  def up
    execute <<~SQL.squish
      INSERT INTO subscriptions (user_id, status, has_used_trial, is_early_subscriber, created_at, updated_at)
      SELECT id, 'free', FALSE, FALSE, NOW(), NOW()
      FROM users
      WHERE id NOT IN (SELECT user_id FROM subscriptions);
    SQL
  end

  # down は危険：単に「status = free」で消すと、Pro 解約 → free に戻った正規データも
  # 巻き込んで削除してしまう。元データを特定する手段がないため、ロールバック不能とする。
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
