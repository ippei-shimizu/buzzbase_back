module Api
  module V2
    class StatsController < Api::V2::ApplicationController
      include MatchTypeConvertible
      before_action :authenticate_api_v1_user!
      before_action :authorize_target_user!
      before_action :require_entitlement!, only: %i[count_situations pitch_types pitcher_faceoffs]

      # 成績内訳の詳細のうちPro限定の3項目（カウント別・球種別・対戦投手別）に必要なentitlement。
      # hit_directions は無料機能のSprayChart（打球方向散布図）も同じレスポンスを使うため
      # エンドポイント自体は無料開放のままにし、詳細テーブル表示のみmobile側でPro判定する。
      ENTITLEMENT_BY_ACTION = {
        count_situations: 'count_situation_average',
        pitch_types: 'pitch_type_average',
        pitcher_faceoffs: 'pitcher_faceoff_average'
      }.freeze

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
        # シーズン粒度（シーズン跨ぎ推移）は Pro 限定。既存の試合/月/年/直近10は無料据え置き。
        if params[:granularity].to_s == 'season' && !current_api_v1_user.has_entitlement?('season_transition_graph')
          return render json: { error: 'シーズン推移は Pro プラン限定です' }, status: :forbidden
        end

        render json: Stats::BattingTrendAggregator.new(
          **aggregator_params, granularity: params[:granularity]
        ).call
      end

      def contact_qualities
        render json: Stats::ContactQualityAggregator.new(**aggregator_params).call
      end

      def timing_breakdown
        render json: Stats::TimingBreakdownAggregator.new(**aggregator_params).call
      end

      def pitch_types
        render json: Stats::PitchTypeAggregator.new(**aggregator_params).call
      end

      def pitcher_faceoffs
        render json: Stats::PitcherFaceoffAggregator.new(**aggregator_params).call
      end

      def pitcher_attribute_summary
        render json: Stats::PitcherAttributeSummaryAggregator.new(**aggregator_params).call
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
          tournament_id: params[:tournament_id],
          start_month: params[:start_month],
          end_month: params[:end_month]
        }
      end

      # batting / pitching テーブル用は period (mode) を追加で受け取り、
      # match_type は使わない（テーブルサービスのインターフェースに合わせる）。
      def table_params
        aggregator_params.except(:match_type).merge(mode: params[:period] || 'yearly')
      end

      def target_user_id
        params[:user_id] || current_api_v1_user.id
      end

      # 自分自身を参照するケース（user_id 未指定）が最頻のため、既に持っている
      # current_api_v1_user を再利用して User.find の追加クエリを避ける。
      def target_user
        @target_user ||= params[:user_id] ? User.find(params[:user_id]) : current_api_v1_user
      end

      # 非公開アカウントの集計データ流出を防ぐ。before_action として使うと
      # render 後に Rails が後続 action を自動で止めるため、明示 return は不要。
      def authorize_target_user!
        render_forbidden_if_private!(target_user)
      end

      # entitlementは閲覧者（current_api_v1_user）のPro加入状況で判定する
      # （他ユーザーの成績を見る場合も、詳細内訳を見られるかは自分のプラン次第）。
      def require_entitlement!
        feature = ENTITLEMENT_BY_ACTION[action_name.to_sym]
        return if current_api_v1_user.has_entitlement?(feature)

        render json: { error: 'この機能は Pro プラン限定です' }, status: :forbidden
      end
    end
  end
end
