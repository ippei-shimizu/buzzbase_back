module Api
  module V1
    module Pro
      # POST /api/v1/pro/checkout
      # Web 加入用の Stripe Checkout Session を生成して checkout_url を返す。
      # 実際の状態遷移は Stripe → RevenueCat → Webhook 経由で行われるため、ここでは local 状態を触らない。
      class CheckoutController < ApplicationController
        before_action :authenticate_api_v1_user!

        def create
          session = App::Stripe::CheckoutSessionBuilder.new(
            user: current_api_v1_user,
            plan: params[:plan],
            success_url: params[:success_url],
            cancel_url: params[:cancel_url]
          ).call

          render json: { checkout_url: session.url }
        rescue App::Stripe::CheckoutSessionBuilder::AlreadySubscribedError
          render json: { error: 'already_subscribed' }, status: :conflict
        rescue App::Stripe::CheckoutSessionBuilder::InvalidPlanError
          render json: { error: 'invalid_plan' }, status: :unprocessable_entity
        rescue ::Stripe::StripeError => e
          # Stripe API 側の障害（一時的ネットワーク・キー誤設定・商品ID不正など）。
          # ユーザーには「決済プロバイダ側の問題」を示し、詳細は Sentry で追えるようにする。
          Sentry.capture_exception(e, tags: { source: 'pro_checkout_controller' })
          render json: { error: 'stripe_api_error' }, status: :bad_gateway
        end
      end
    end
  end
end
