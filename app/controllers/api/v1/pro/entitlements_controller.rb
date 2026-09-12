module Api
  module V1
    module Pro
      # GET /api/v1/pro/entitlements
      # 全 entitlement キーごとに granted フラグを返す。
      # クライアント側で個別画面の出し分けや paywall 表示を判定するために使う。
      class EntitlementsController < ApplicationController
        before_action :authenticate_api_v1_user!

        def index
          user = current_api_v1_user
          entitlements = ::Entitlement::ALL_FEATURES.map do |key|
            { key:, granted: user.has_entitlement?(key) }
          end

          render json: { entitlements: }, status: :ok
        end
      end
    end
  end
end
