module Api
  module V2
    # 試合結果 v2 API コントローラー
    #
    # v1との違い:
    # - opponent_team_name, tournament_name, plate_appearances をレスポンスに含める
    # - フロントエンド側でN+1 HTTPリクエスト（チーム名・大会名・打席結果を個別取得）を不要にする
    # - シリアライザー(V2::GameResultSerializer)を使用してレスポンス形式を制御する
    class GameResultsController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[index filtered_index]

      # GET /api/v2/game_results
      # 認証ユーザー自身の試合一覧を取得する
      def index
        game_results = GameResult.v2_game_associated_data_user(current_api_v1_user)
        render json: game_results, each_serializer: ::V2::GameResultSerializer
      end

      # GET /api/v2/game_results/all
      # 全ユーザーの試合一覧を取得する（タイムライン表示用）
      def all
        game_results = GameResult.v2_all_game_associated_data
        render json: game_results, each_serializer: ::V2::AllGameResultSerializer
      end

      # GET /api/v2/game_results/filtered_index
      # 認証ユーザー自身の試合一覧を年度・試合種別でフィルタして取得する
      # @param year [String] フィルタ対象の年度
      # @param match_type [String] フィルタ対象の試合種別（"公式戦"/"オープン戦"）
      def filtered_index
        year = params[:year]
        match_type = convert_match_type(params[:match_type])
        game_results = GameResult.v2_filtered_game_associated_data_user(current_api_v1_user, year, match_type)
        render json: game_results, each_serializer: ::V2::GameResultSerializer
      end

      # GET /api/v2/game_results/user/:user_id
      # 指定ユーザーの試合一覧を取得する
      # @param user_id [Integer] 対象ユーザーのID
      def show_user
        user_id = params[:user_id]
        game_results = GameResult.v2_game_associated_data_user(user_id)
        render json: game_results, each_serializer: ::V2::GameResultSerializer
      end

      # GET /api/v2/game_results/filtered_user/:user_id
      # 指定ユーザーの試合一覧を年度・試合種別でフィルタして取得する
      # @param user_id [Integer] 対象ユーザーのID
      # @param year [String] フィルタ対象の年度
      # @param match_type [String] フィルタ対象の試合種別（"公式戦"/"オープン戦"）
      def filtered_show_user
        user_id = params[:user_id]
        year = params[:year]
        match_type = convert_match_type(params[:match_type])
        game_results = GameResult.v2_filtered_game_associated_data_user(user_id, year, match_type)
        render json: game_results, each_serializer: ::V2::GameResultSerializer
      end

      private

      # フロントエンドから送られる日本語の試合種別をDB値に変換する
      # @param match_type [String] "公式戦" | "オープン戦" | その他
      # @return [String] "regular" | "open" | そのまま返却
      def convert_match_type(match_type)
        case match_type
        when '公式戦'
          'regular'
        when 'オープン戦'
          'open'
        else
          match_type
        end
      end
    end
  end
end
