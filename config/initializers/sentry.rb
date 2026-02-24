if ENV['SENTRY_DSN']

  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f

    config.environment = Rails.env
    config.release = ENV['HEROKU_RELEASE_VERSION'] || ENV['SENTRY_RELEASE']
    config.enabled_environments = %w[production]
    config.send_default_pii = false

    config.excluded_exceptions += %w[
      ActionController::RoutingError
      ActiveRecord::RecordNotFound
      ActionController::UnknownFormat
      ActionController::InvalidAuthenticityToken
      Mime::Type::InvalidMIMEType
    ]
  end

end
