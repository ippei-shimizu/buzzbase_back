module Api
  module V2
    class StatsController < ApplicationController
      before_action :authenticate_api_v1_user!

      def hit_directions
        result = Stats::HitDirectionAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: params[:match_type],
          season_id: params[:season_id]
        ).call
        render json: result
      end

      def plate_appearance_breakdown
        result = Stats::PlateAppearanceBreakdownService.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: params[:match_type],
          season_id: params[:season_id]
        ).call
        render json: { breakdown: result }
      end

      def batting
        result = Stats::BattingStatsTableService.new(
          user_id: target_user_id,
          mode: params[:period] || 'yearly',
          year: params[:year],
          season_id: params[:season_id]
        ).call
        render json: { rows: result }
      end

      def pitching
        result = Stats::PitchingStatsTableService.new(
          user_id: target_user_id,
          mode: params[:period] || 'yearly',
          year: params[:year],
          season_id: params[:season_id]
        ).call
        render json: { rows: result }
      end

      def era_trend
        result = Stats::EraTrendService.new(
          user_id: target_user_id,
          year: params[:year],
          season_id: params[:season_id]
        ).call
        render json: { trend: result }
      end

      def game_summary
        result = Stats::GameSummaryService.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: params[:match_type],
          season_id: params[:season_id]
        ).call
        render json: result
      end

      private

      def target_user_id
        params[:user_id] || current_api_v1_user.id
      end
    end
  end
end
