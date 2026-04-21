module Api
  module V2
    # 試合結果 v2 API コントローラー
    #
    # v1との違い:
    # - opponent_team_name, tournament_name, plate_appearances をレスポンスに含める
    # - フロントエンド側でN+1 HTTPリクエスト（チーム名・大会名・打席結果を個別取得）を不要にする
    # - シリアライザー(V2::GameResultSerializer)を使用してレスポンス形式を制御する
    # - ページネーション対応（kaminari）
    class GameResultsController < ApplicationController
      include MatchTypeConvertible
      before_action :authenticate_api_v1_user!, only: %i[index filtered_index show_user filtered_show_user]

      # GET /api/v2/game_results
      # 認証ユーザー自身の試合一覧を取得する
      def index
        game_results = GameResult.v2_game_associated_data_user(current_api_v1_user)
                                 .page(params[:page]).per(params[:per_page])
        render json: paginated_response(game_results, ::V2::GameResultSerializer)
      end

      # GET /api/v2/game_results/all
      # 全ユーザーの試合一覧を取得する（タイムライン表示用）
      def all
        game_results = GameResult.v2_all_game_associated_data_public
                                 .page(params[:page]).per(params[:per_page])
        render json: paginated_response(game_results, ::V2::AllGameResultSerializer)
      end

      # GET /api/v2/game_results/filtered_index
      # 認証ユーザー自身の試合一覧を年度・試合種別でフィルタして取得する
      # @param year [String] フィルタ対象の年度
      # @param match_type [String] フィルタ対象の試合種別（"公式戦"/"オープン戦"）
      def filtered_index
        year = params[:year]
        match_type = convert_match_type(params[:match_type])
        season_id = params[:season_id]
        tournament_id = params[:tournament_id]
        game_results = GameResult.v2_filtered_game_associated_data_user(current_api_v1_user, year, match_type, season_id, tournament_id:)
        game_results = game_results.search_by_opponent(params[:search]) if params[:search].present?
        game_results = game_results.reorder(nil).apply_sort(params[:sort_by], params[:sort_order]) if params[:sort_by].present?
        game_results = game_results.page(params[:page]).per(params[:per_page])
        render json: paginated_response(game_results, ::V2::GameResultSerializer)
      end

      # GET /api/v2/game_results/user/:user_id
      # 指定ユーザーの試合一覧を取得する
      # @param user_id [Integer] 対象ユーザーのID
      def show_user
        user = User.find(params[:user_id])
        return render json: { error: 'このアカウントは非公開です' }, status: :forbidden unless user.profile_visible_to?(current_api_v1_user)

        game_results = GameResult.v2_game_associated_data_user(user)
                                 .page(params[:page]).per(params[:per_page])
        render json: paginated_response(game_results, ::V2::GameResultSerializer)
      end

      # GET /api/v2/game_results/filtered_user/:user_id
      # 指定ユーザーの試合一覧を年度・試合種別でフィルタして取得する
      # @param user_id [Integer] 対象ユーザーのID
      # @param year [String] フィルタ対象の年度
      # @param match_type [String] フィルタ対象の試合種別（"公式戦"/"オープン戦"）
      def filtered_show_user
        user = User.find(params[:user_id])
        return render json: { error: 'このアカウントは非公開です' }, status: :forbidden unless user.profile_visible_to?(current_api_v1_user)

        year = params[:year]
        match_type = convert_match_type(params[:match_type])
        season_id = params[:season_id]
        tournament_id = params[:tournament_id]
        game_results = GameResult.v2_filtered_game_associated_data_user(user, year, match_type, season_id, tournament_id:)
        game_results = game_results.search_by_opponent(params[:search]) if params[:search].present?
        game_results = game_results.reorder(nil).apply_sort(params[:sort_by], params[:sort_order]) if params[:sort_by].present?
        game_results = game_results.page(params[:page]).per(params[:per_page])
        render json: paginated_response(game_results, ::V2::GameResultSerializer)
      end

      private

      def paginated_response(game_results, serializer)
        {
          data: ActiveModelSerializers::SerializableResource.new(game_results, each_serializer: serializer),
          pagination: {
            current_page: game_results.current_page,
            per_page: game_results.limit_value,
            total_count: game_results.total_count,
            total_pages: game_results.total_pages
          }
        }
      end
    end
  end
end
