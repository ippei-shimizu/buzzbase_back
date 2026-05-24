module App
  module Stripe
    module Handlers
      # checkout.session.completed: Web 加入完了時に Stripe ID 2 つを Subscription に紐付ける。
      # status / plan_type 等の状態遷移は RevenueCat 経由で更新されるため、ここでは Stripe ID のみ保存する。
      class CheckoutSessionCompletedHandler < BaseHandler
        def call
          user_id = payload.metadata[:user_id]
          return notify_missing_user_id if user_id.blank?

          user = User.find_by(id: user_id)
          return notify_unknown_user(user_id) unless user

          user.subscription_or_default.update!(
            stripe_customer_id: payload.customer_id,
            stripe_subscription_id: payload.subscription_id
          )
        end

        private

        def notify_missing_user_id
          Sentry.capture_message(
            'Stripe checkout.session.completed: metadata.user_id is missing',
            level: :warning
          )
          nil
        end

        def notify_unknown_user(user_id)
          Sentry.capture_message(
            "Stripe checkout.session.completed: user not found for user_id=#{user_id.inspect}",
            level: :warning
          )
          nil
        end
      end
    end
  end
end
