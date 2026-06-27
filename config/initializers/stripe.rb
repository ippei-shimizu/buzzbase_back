Stripe.api_key =
  if ENV['USE_STRIPE_TEST_MODE'] == 'true' || !Rails.env.production?
    # テストモード時に本番キーへフォールバックすると事故になるため、必ず test key のみ参照する。
    ENV.fetch('STRIPE_SECRET_KEY_TEST', nil)
  else
    ENV.fetch('STRIPE_SECRET_KEY', nil)
  end

Stripe.api_version = '2024-06-20'
