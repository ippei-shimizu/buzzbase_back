module Api
  module V1
    # GET /api/v1/feature_flags?keys[]=pro_features&keys[]=cancellation_survey
    # mobile / front が UI の出し分け（Pro 機能表示・解約アンケート表示など）を行うため、
    # Flipper の判定結果を current_api_v1_user 単位で返す。
    class FeatureFlagsController < ApplicationController
      before_action :authenticate_api_v1_user!

      # クライアントに公開してよい flag のホワイトリスト。
      # Flipper の予約済みキー（社内検証用 flag 等）と切り離す目的で controller 側に持たせる。
      PUBLIC_KEYS = %w[pro_features cancellation_survey].freeze

      def index
        requested = Array(filter_params[:keys]).map(&:to_s) & PUBLIC_KEYS
        render json: requested.index_with { |key| Flipper.enabled?(key.to_sym, current_api_v1_user) }
      end

      private

      def filter_params
        params.permit(keys: [])
      end
    end
  end
end
