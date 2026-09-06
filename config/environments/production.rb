require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  # :debug は全 SQL とバインドパラメータがログに流れ、ログ流量・レイテンシ・PII 露出の
  # リスクがあるため既定は :info。障害調査時は RAILS_LOG_LEVEL=debug で一時的に切り替える。
  # 不正な値をそのまま to_sym すると Logger が boot 時に例外を投げ、config var の打ち間違い
  # ひとつで全 dyno がクラッシュループに入るため、許可リスト外は既定値へ倒す。
  valid_log_levels = %w[debug info warn error fatal unknown]
  config.log_level = valid_log_levels.include?(ENV['RAILS_LOG_LEVEL']) ? ENV['RAILS_LOG_LEVEL'].to_sym : :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Heroku dyno のファイルシステムは ephemeral かつ dyno ごとに独立のため、既定の
  # file_store はキャッシュとして実質機能しない。REDIS_URL（Action Cable と共用の
  # アドオン）があれば redis_cache_store を使い、無ければ memory_store を明示する
  # （dyno ごとに独立・再起動で消える前提を許容できる用途に限る）。
  # Redis 側の障害でリクエストを巻き込まないよう、タイムアウトを短く明示し、
  # エラーはキャッシュミス扱いで握り潰して Sentry に記録する。
  if ENV['REDIS_URL'].present?
    redis_cache_options = {
      url: ENV['REDIS_URL'],
      # Action Cable (cable.yml) と同一インスタンスを共有するため、キー空間を分ける。
      namespace: 'cache',
      # Heroku Key-Value Store はプランによって maxmemory-policy が noeviction で、
      # TTL 無しのキーが増え続けると Action Cable の pub/sub ごと書き込み不能になる。
      # 個別に expires_in を渡さない呼び出しのための既定の上限。
      expires_in: 1.hour,
      connect_timeout: 1,
      read_timeout: 1,
      write_timeout: 1,
      reconnect_attempts: 1,
      # returning にはキャッシュ対象の値そのものが入りうる。Sentry の tag は
      # 検索用の短い文字列を前提とした領域なので、値ではなく型だけを載せる。
      error_handler: lambda { |method:, returning:, exception:|
        if Sentry.initialized?
          Sentry.capture_exception(exception, level: :warning,
                                              tags: { cache_method: method },
                                              extra: { returning_class: returning.class.name })
        end
      }
    }
    # Heroku Key-Value Store の TLS (rediss://) は自己署名証明書のため、Heroku の
    # ドキュメントに従い検証を無効化する。検証可能な Redis に差し替えたときに無効化が
    # 残り続けないよう、TLS で接続するときだけ付与する。
    redis_cache_options[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE } if ENV['REDIS_URL'].start_with?('rediss://')

    config.cache_store = [:redis_cache_store, redis_cache_options]
  else
    config.cache_store = :memory_store
  end

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # queue_adapter は config/application.rb で全環境一括設定済み。
  # Solid Queue 用テーブルはアプリ DB に同居させるため connects_to は設定しない。
  # config.active_job.queue_name_prefix = "app_production"

  config.action_mailer.perform_caching = false

  Rails.application.config.hosts << 'www.buzzbase.jp'
  config.hosts << 'mysterious-hollows-68593-7476ce827bc4.herokuapp.com'

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.default_url_options = { host: 'mysterious-hollows-68593-7476ce827bc4.herokuapp.com', protocol: 'https' }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp.gmail.com',
    port: 587,
    domain: 'mysterious-hollows-68593-7476ce827bc4.herokuapp.com',
    user_name: ENV.fetch('GMAIL_USERNAME', nil),
    password: ENV.fetch('GMAIL_PASSWORD', nil),
    authentication: :plain,
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end
