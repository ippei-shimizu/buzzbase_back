# User のメールアドレスが変わったとき、Stripe Customer.email を追従させる。
# Stripe からの請求書・領収書を新しいメールへ正しく届けるための同期処理。
# User#update! を巻き込まないよう Job 内で例外を握り潰す（fire-and-forget）。
class StripeCustomerUpdateJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    stripe_customer_id = user.subscription&.stripe_customer_id
    return if stripe_customer_id.blank?

    Stripe::Customer.update(stripe_customer_id, email: user.email)
  rescue StandardError => e
    Sentry.capture_exception(e, tags: { source: 'stripe_customer_update', user_id: })
  end
end
