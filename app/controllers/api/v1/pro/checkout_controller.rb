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
        end
      end
    end
  end
end
