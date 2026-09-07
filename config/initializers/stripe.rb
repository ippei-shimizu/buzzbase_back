Stripe.api_key =
  if ENV['USE_STRIPE_TEST_MODE'] == 'true' || !Rails.env.production?
    # テストモード時に本番キーへフォールバックすると事故になるため、必ず test key のみ参照する。
    ENV.fetch('STRIPE_SECRET_KEY_TEST', nil)
  else
    ENV.fetch('STRIPE_SECRET_KEY', nil)
  end

Stripe.api_version = '2024-06-20'

# gem 既定 (open 30秒 / read 80秒) は Stripe 側が詰まったときに Puma スレッドと
# DB コネクションを長時間占有するため短く明示する。Checkout Session 作成・解約等の
# 呼び出しはいずれも軽量 API のため read 10秒で十分。
Stripe.open_timeout = 5
Stripe.read_timeout = 10
