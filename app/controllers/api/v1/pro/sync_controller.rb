module Api
  module V1
    module Pro
      # POST /api/v1/pro/sync
      # クライアントから「RevenueCat と Rails の状態を再同期してくれ」と要求する暫定エンドポイント。
      # 本実装は #318 で RevenueCat REST API を叩いて状態を取得・反映する形に差し替える予定。
      # 本 Issue では last_synced_at の刻印と現在状態の返却だけを行うスタブとする。
      class SyncController < ApplicationController
        before_action :authenticate_api_v1_user!

        def create
          user = current_api_v1_user
          subscription = user.subscription || user.create_subscription!(status: 'free')
          subscription.update!(last_synced_at: Time.current)

          render json: {
            subscription: ::V1::SubscriptionSerializer.new(subscription).as_json,
            entitlements: ::Entitlement::ALL_FEATURES.select { |key| user.has_entitlement?(key) }
          }, status: :ok
        end
      end
    end
  end
end
