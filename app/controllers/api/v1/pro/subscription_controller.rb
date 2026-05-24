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
          head :ok
        rescue App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError
          render json: { error: 'no_active_subscription' }, status: :unprocessable_entity
        rescue App::Stripe::SubscriptionUpdater::InvalidPlanError
          render json: { error: 'invalid_plan' }, status: :unprocessable_entity
        end

        def destroy
          App::Stripe::SubscriptionUpdater.new(current_api_v1_user).cancel_at_period_end
          head :ok
        rescue App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError
          render json: { error: 'no_active_subscription' }, status: :unprocessable_entity
        end
      end
    end
  end
end
