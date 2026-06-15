module Api
  module V2
    class StatsController < Api::V2::ApplicationController
      include MatchTypeConvertible
      before_action :authenticate_api_v1_user!

      def hit_directions
        render json: Stats::HitDirectionAggregator.new(**aggregator_params).call
      end

      def plate_appearance_breakdown
        render json: { breakdown: Stats::PlateAppearanceBreakdownService.new(**aggregator_params).call }
      end

      def batting
        render json: { rows: Stats::BattingStatsTableService.new(**table_params).call }
      end

      def pitching
        render json: { rows: Stats::PitchingStatsTableService.new(**table_params).call }
      end

      def era_trend
        render json: { trend: Stats::EraTrendService.new(**aggregator_params.except(:match_type)).call }
      end

      def game_summary
        render json: Stats::GameSummaryService.new(**aggregator_params).call
      end

      def headline_stats
        render json: Stats::HeadlineStatsAggregator.new(**aggregator_params).call
      end

      def additional_stats
        render json: Stats::AdditionalStatsAggregator.new(**aggregator_params).call
      end

      def runners_situation
        render json: Stats::RunnersSituationAggregator.new(**aggregator_params).call
      end

      def hit_locations
        render json: Stats::HitLocationAggregator.new(**aggregator_params).call
      end

      def out_type_breakdown
        render json: Stats::OutTypeBreakdownService.new(**aggregator_params).call
      end

      def count_situations
        render json: Stats::CountSituationAggregator.new(**aggregator_params).call
      end

      def batting_trend
        render json: Stats::BattingTrendAggregator.new(
          **aggregator_params, granularity: params[:granularity]
        ).call
      end

      def contact_qualities
        render json: Stats::ContactQualityAggregator.new(**aggregator_params).call
      end

      def pitch_types
        render json: Stats::PitchTypeAggregator.new(**aggregator_params).call
      end

      def pitcher_faceoffs
        render json: Stats::PitcherFaceoffAggregator.new(**aggregator_params).call
      end

      private

      # 各 Stats:: 系サービスが共通で受け取るパラメータ。
      # action ごとに同じ 5 項目を毎回書くと controller が肥大化するため集約する。
      def aggregator_params
        {
          user_id: target_user_id,
          year: params[:year],
          match_type: convert_match_type(params[:match_type]),
          season_id: params[:season_id],
          tournament_id: params[:tournament_id]
        }
      end

      # batting / pitching テーブル用は period (mode) を追加で受け取り、
      # match_type は使わない（テーブルサービスのインターフェースに合わせる）。
      def table_params
        aggregator_params.except(:match_type).merge(mode: params[:period] || 'yearly')
      end

      # 他ユーザーの成績も参照可能（公開プロフィール設計）
      # プライベートアカウント対応時はprofile_visible_to?チェックを追加する
      def target_user_id
        params[:user_id] || current_api_v1_user.id
      end
    end
  end
end
