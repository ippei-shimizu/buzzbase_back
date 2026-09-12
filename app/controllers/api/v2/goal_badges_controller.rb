module Api
  module V2
    # 目標達成バッジの閲覧。付与はFinalizeGoalsJobが行い、ここは一覧取得のみ。
    class GoalBadgesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        badges = current_api_v1_user.goal_badges.includes(:goal).order(awarded_at: :desc)
        render json: badges, each_serializer: ::V2::GoalBadgeSerializer, status: :ok
      end
    end
  end
end
