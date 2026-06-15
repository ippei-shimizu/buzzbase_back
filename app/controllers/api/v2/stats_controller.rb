module Api
  module V2
    class StatsController < Api::V2::ApplicationController
      include MatchTypeConvertible
      before_action :authenticate_api_v1_user!

      def hit_directions
        result = Stats::HitDirectionAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def plate_appearance_breakdown
        result = Stats::PlateAppearanceBreakdownService.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: { breakdown: result }
      end

      def batting
        result = Stats::BattingStatsTableService.new(
          user_id: target_user_id,
          mode: params[:period] || 'yearly',
          year: params[:year],
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: { rows: result }
      end

      def pitching
        result = Stats::PitchingStatsTableService.new(
          user_id: target_user_id,
          mode: params[:period] || 'yearly',
          year: params[:year],
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: { rows: result }
      end

      def era_trend
        result = Stats::EraTrendService.new(
          user_id: target_user_id,
          year: params[:year],
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: { trend: result }
      end

      def game_summary
        result = Stats::GameSummaryService.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def headline_stats
        result = Stats::HeadlineStatsAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def runners_situation
        result = Stats::RunnersSituationAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def hit_locations
        result = Stats::HitLocationAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def out_type_breakdown
        result = Stats::OutTypeBreakdownService.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def count_situations
        result = Stats::CountSituationAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def contact_qualities
        result = Stats::ContactQualityAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def pitch_types
        result = Stats::PitchTypeAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      def pitcher_faceoffs
        result = Stats::PitcherFaceoffAggregator.new(
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        ).call
        render json: result
      end

      private

      # 他ユーザーの成績も参照可能（公開プロフィール設計）
      # プライベートアカウント対応時はprofile_visible_to?チェックを追加する
      def target_user_id
        params[:user_id] || current_api_v1_user.id
      end
    end
  end
end
