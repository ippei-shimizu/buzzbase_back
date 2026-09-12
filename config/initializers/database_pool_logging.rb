# Heroku では DATABASE_URL の `?pool=` が database.yml の pool より優先されるため、
# 実際に適用された値を起動時に残しておかないと設定の食い違いに気付けない。
# connection_db_config は解決済みの設定を読むだけでコネクションを掴まない。
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  Rails.logger.info("DB connection pool size: #{ActiveRecord::Base.connection_db_config.pool}")
end
