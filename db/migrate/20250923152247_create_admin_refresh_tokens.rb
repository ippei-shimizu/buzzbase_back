class CreateAdminRefreshTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :admin_refresh_tokens do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :jti, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :admin_refresh_tokens, :jti, unique: true
    add_index :admin_refresh_tokens, :expires_at
    add_index :admin_refresh_tokens, [:admin_user_id, :expires_at]
  end
end
