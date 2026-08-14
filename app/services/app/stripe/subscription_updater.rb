module App
  module Stripe
    # Stripe Subscription を更新する API ラッパー（解約 / プラン変更）。
    # local 状態の更新は Webhook 経由で正規化されるため、ここでは Stripe API 呼び出しに専念する。
    class SubscriptionUpdater
      NoStripeSubscriptionError = Class.new(StandardError)
      InvalidPlanError = Class.new(StandardError)

      VALID_PLANS = %w[monthly yearly].freeze

      def initialize(user)
        @user = user
      end

      # 解約申請。期限まで Pro 機能利用可（cancel_at_period_end）。
      def cancel_at_period_end
        ::Stripe::Subscription.update(stripe_subscription_id!, cancel_at_period_end: true)
      end

      # プラン変更（月額↔年額）。proration_behavior は Stripe の差額計算に任せる。
      def change_plan(new_plan)
        raise InvalidPlanError unless VALID_PLANS.include?(new_plan)

        # stripe_item_id を保持していないため都度 retrieve で取得する（シンプルさ優先）。
        sub = ::Stripe::Subscription.retrieve(stripe_subscription_id!)
        item_id = sub.items.data.first.id

        ::Stripe::Subscription.update(
          stripe_subscription_id!,
          items: [{ id: item_id, price: stripe_price_id(new_plan) }],
          proration_behavior: 'create_prorations'
        )
      end

      private

      def stripe_subscription_id!
        id = @user.subscription_or_default.stripe_subscription_id
        raise NoStripeSubscriptionError if id.blank?

        id
      end

      def stripe_price_id(plan)
        case plan
        when 'monthly' then ENV.fetch('STRIPE_PRICE_ID_MONTHLY')
        when 'yearly'  then ENV.fetch('STRIPE_PRICE_ID_YEARLY')
        end
      end
    end
  end
end
