Stripe.api_key =
  if ENV['USE_STRIPE_TEST_MODE'] == 'true' || !Rails.env.production?
    ENV.fetch('STRIPE_SECRET_KEY_TEST', ENV.fetch('STRIPE_SECRET_KEY', nil))
  else
    ENV.fetch('STRIPE_SECRET_KEY', nil)
  end

Stripe.api_version = '2024-06-20'
