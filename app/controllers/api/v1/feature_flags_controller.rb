module Api
  module V1
    # GET /api/v1/feature_flags?keys[]=pro_features
    #
    # Flipper 撤去後の互換エンドポイント。ストア配信済みの旧アプリは取得失敗時に
    # enabled = false へ倒す設計のため、エンドポイントを即削除すると旧バージョンの
    # Pro 購入導線が消えてしまう。旧バージョンが十分に減るまで残し、固定値を返す。
    class FeatureFlagsController < ApplicationController
      before_action :authenticate_api_v1_user!

      # クライアントに公開する flag と固定値。pro_features は恒久有効（kill switch 廃止）。
      PUBLIC_FLAGS = { 'pro_features' => true }.freeze

      def index
        requested = Array(filter_params[:keys]) & PUBLIC_FLAGS.keys
        render json: requested.index_with { |key| PUBLIC_FLAGS[key] }
      end

      private

      def filter_params
        params.permit(keys: [])
      end
    end
  end
end
