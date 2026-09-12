module Api
  module V1
    module Pro
      # DELETE /api/v1/pro/subscription : Web で解約申請（cancel_at_period_end）
      # PATCH  /api/v1/pro/subscription : 月額↔年額のプラン変更
      # local 状態は Webhook 経由で正規化されるため、ここでは Stripe API 呼び出しのみ行う。
      class SubscriptionController < ApplicationController
        before_action :authenticate_api_v1_user!

        def update
          App::Stripe::SubscriptionUpdater.new(current_api_v1_user).change_plan(params[:plan])
          render json: { message: 'プラン変更を受け付けました' }, status: :ok
        rescue App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError
          render json: { error: 'no_active_subscription' }, status: :unprocessable_entity
        rescue App::Stripe::SubscriptionUpdater::InvalidPlanError
          render json: { error: 'invalid_plan' }, status: :unprocessable_entity
        rescue ::Stripe::StripeError => e
          Sentry.capture_exception(e, tags: { source: 'pro_subscription_controller', action: 'update' })
          render json: { error: 'stripe_api_error' }, status: :bad_gateway
        end

        def destroy
          App::Stripe::SubscriptionUpdater.new(current_api_v1_user).cancel_at_period_end
          render json: { message: '解約申請を受け付けました' }, status: :ok
        rescue App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError
          render json: { error: 'no_active_subscription' }, status: :unprocessable_entity
        rescue ::Stripe::StripeError => e
          Sentry.capture_exception(e, tags: { source: 'pro_subscription_controller', action: 'destroy' })
          render json: { error: 'stripe_api_error' }, status: :bad_gateway
        end
      end
    end
  end
end
