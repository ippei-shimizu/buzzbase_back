module Api
  module V1
    module Pro
      # GET /api/v1/pro/status
      # 現在ユーザーの Pro 状態と保有 Entitlement を返す。
      class StatusController < ApplicationController
        before_action :authenticate_api_v1_user!

        def show
          user = current_api_v1_user
          subscription = user.subscription_or_default

          render json: {
            subscription: ActiveModelSerializers::SerializableResource.new(
              subscription,
              serializer: ::V1::SubscriptionSerializer
            ).as_json,
            entitlements: granted_entitlement_keys(user)
          }, status: :ok
        end

        private

        # ユーザーが現在保有している entitlement キーのリスト。
        # 無料機能は常に含まれ、Pro 機能は pro_active? のときのみ含まれる。
        def granted_entitlement_keys(user)
          ::Entitlement::ALL_FEATURES.select { |key| user.has_entitlement?(key) }
        end
      end
    end
  end
end
