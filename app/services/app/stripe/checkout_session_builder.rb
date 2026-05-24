module App
  module Stripe
    # Stripe Checkout Session を生成するサービス。
    # ・既加入ガード
    # ・plan 妥当性チェック
    # ・TrialDaysCalculator を参照して trial_period_days を決定
    # を一手に引き受け、Controller を薄く保つ。
    class CheckoutSessionBuilder
      AlreadySubscribedError = Class.new(StandardError)
      InvalidPlanError = Class.new(StandardError)

      VALID_PLANS = %w[monthly yearly].freeze

      def initialize(user:, plan:, success_url:, cancel_url:)
        @user = user
        @plan = plan
        @success_url = success_url
        @cancel_url = cancel_url
      end

      def call
        raise InvalidPlanError unless VALID_PLANS.include?(@plan)
        raise AlreadySubscribedError if @user.subscription_or_default.pro_active?

        ::Stripe::Checkout::Session.create(checkout_params)
      end

      private

      def checkout_params
        {
          mode: 'subscription',
          customer_email: @user.email,
          line_items: [{ price: stripe_price_id, quantity: 1 }],
          subscription_data:,
          success_url: @success_url,
          cancel_url: @cancel_url
        }
      end

      # trial_period_days は 0 なら Stripe に渡さない（compact で除去）。
      # 0 のまま渡すと「即時課金」ではなく「0日トライアル後課金」と解釈される可能性があるため。
      def subscription_data
        trial_days = TrialDaysCalculator.for(@user)
        {
          trial_period_days: trial_days.positive? ? trial_days : nil,
          metadata: { user_id: @user.id.to_s, plan: @plan }
        }.compact
      end

      def stripe_price_id
        case @plan
        when 'monthly' then ENV.fetch('STRIPE_PRICE_ID_MONTHLY')
        when 'yearly'  then ENV.fetch('STRIPE_PRICE_ID_YEARLY')
        end
      end
    end
  end
end
