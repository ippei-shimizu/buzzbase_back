module Api
  module V1
    module Pro
      # POST /api/v1/pro/sync
      # クライアントから「RevenueCat と Rails の状態を再同期してくれ」と要求されたときに、
      # RevenueCat REST API から現在のsubscriber状態を取得してSubscriptionへ反映する。
      # Webhookの取りこぼし・配信遅延時に、クライアント側の「同期更新」ボタンから叩く想定。
      class SyncController < ApplicationController
        before_action :authenticate_api_v1_user!

        def create
          user = current_api_v1_user
          subscription = RevenueCat::SubscriberSync.new(user).call

          render json: {
            subscription: ::V1::SubscriptionSerializer.new(subscription).as_json,
            entitlements: ::Entitlement::ALL_FEATURES.select { |key| user.has_entitlement?(key) }
          }, status: :ok
        rescue RevenueCat::SubscriberClient::RequestFailedError => e
          Sentry.capture_exception(e, tags: { source: 'pro_sync_controller' })
          render json: { error: 'revenuecat_api_error' }, status: :bad_gateway
        end
      end
    end
  end
end
