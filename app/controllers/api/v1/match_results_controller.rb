module Api
  module V1
    class MatchResultsController < ApplicationController
      include MatchTypeConvertible

      before_action :authenticate_api_v1_user!, only: %i[create update destroy existing_search current_game_result_search current_user_match_index match_index_user_id user_game_result_search available_years form_defaults]
      before_action :set_match_result, only: %i[show]
      before_action :set_owned_match_result, only: %i[update destroy]
      before_action :normalize_match_type, only: %i[create update]

      def index
        @match_results = MatchResult.includes(:user, :tournament, :my_team, :opponent_team)
        render json: @match_results
      end

      def show
        return render json: { errors: ['リソースが見つかりません'] }, status: :not_found if @match_result.nil?

        render json: @match_result
      end

      def create
        @match_result = MatchResult.new(match_results_params.merge(user_id: current_api_v1_user.id))
        if @match_result.save
          render json: @match_result, status: :created
        else
          render json: { errors: @match_result.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        return render json: { errors: ['リソースが見つかりません'] }, status: :not_found if @match_result.nil?

        if @match_result.update(match_results_params)
          render json: @match_result
        else
          render json: { errors: @match_result.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/match_results/:id
      # 冪等化: 既に削除済みでも 200 を返す。所有権スコープは set_owned_match_result で適用済み。
      # @return [JSON] { message: String } または { errors: Array<String> }
      def destroy
        return render json: { message: '試合情報は既に削除されています' }, status: :ok if @match_result.nil?

        if @match_result.destroy
          render json: { message: '試合情報を削除しました' }, status: :ok
        else
          render json: { errors: @match_result.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def match_index_user_id
        user = User.find(params[:user_id])
        return render json: { error: 'このアカウントは非公開です' }, status: :forbidden unless user.profile_visible_to?(current_api_v1_user)

        match_results = MatchResult.where(user_id: user.id).includes(:user, :tournament, :my_team, :opponent_team)
        render json: match_results
      end

      # GET /api/v1/match_results/available_years
      # 指定ユーザー（またはログインユーザー）の試合データに紐づく年度一覧を返す
      def available_years
        user = params[:user_id].present? ? User.find_by(id: params[:user_id]) : current_api_v1_user
        return render json: { error: 'ユーザーが存在しません' }, status: :not_found unless user
        unless user == current_api_v1_user || user.profile_visible_to?(current_api_v1_user)
          return render json: { error: 'このアカウントは非公開です' }, status: :forbidden
        end

        years = MatchResult.available_years_for(user)
        render json: years.map(&:to_s)
      end

      def existing_search
        @match_result = MatchResult.find_by(game_result_id: params[:game_result_id], user_id: params[:user_id])
        if @match_result
          game_result = GameResult.includes(:season).find_by(id: params[:game_result_id])
          season_id = game_result&.season_id
          render json: @match_result.as_json.merge(season_id:)
        else
          render json: { message: 'No matching record found' }, status: :not_found
        end
      end

      def current_game_result_search
        if params[:game_result_id]
          game_result = GameResult.includes(:season).find_by(id: params[:game_result_id])
          match_result = MatchResult.where(game_result_id: params[:game_result_id], user_id: current_api_v1_user.id)
          if match_result.present?
            season_name = game_result&.season&.name
            render json: match_result.map { |mr| mr.as_json.merge(season_name:) }
          else
            render json: { message: '試合情報が見つかりません。' }, status: :not_found
          end
        else
          render json: { error: '試合情報が見つかりません。' }, status: :bad_request
        end
      end

      def user_game_result_search
        if params[:game_result_id]
          game_result = GameResult.includes(:season).find_by(id: params[:game_result_id])
          if game_result
            user = game_result.user
            return render json: { error: 'このアカウントは非公開です' }, status: :forbidden unless user.profile_visible_to?(current_api_v1_user)
          end
          match_result = MatchResult.where(game_result_id: params[:game_result_id])
          if match_result.present?
            season_name = game_result&.season&.name
            render json: match_result.map { |mr| mr.as_json.merge(season_name:) }
          else
            render json: { message: '試合情報が見つかりません。' }, status: :not_found
          end
        else
          render json: { error: '試合情報が見つかりません。' }, status: :bad_request
        end
      end

      def current_user_match_index
        @match_results = MatchResult.where(use_id: current_api_v1_user).includes(:user, :tournament, :my_team, :opponent_team)
        render json: @match_results
      end

      # GET /api/v1/match_results/form_defaults
      # 試合作成フォームの初期値を返す。現状は直近試合のイニング制（7 or 9）。
      # 履歴がない場合は 9 をデフォルトとして返す。
      # フォーム初期値を増やしたくなった際にこのエンドポイントに値を追加していく想定。
      # @return [JSON] { inning_format: Integer }
      def form_defaults
        latest = current_api_v1_user.match_results.order(date_and_time: :desc).first
        render json: { inning_format: latest&.inning_format || 9 }
      end

      private

      # show 用: 認証なしでもアクセス可能なため、ユーザースコープで絞らずに取得する。
      # 取得後の表示可否は、必要に応じて呼び出し元で判断する。
      def set_match_result
        @match_result = MatchResult.find_by(id: params[:id])
      end

      # update / destroy 用: 認証ユーザー所有の match_result のみを対象にする。
      # 他ユーザーのリソースや存在しない id は nil として扱い、各アクションで 404 / 200 にハンドルする。
      # 「他人のもの」と「存在しない」を区別しないことで、id 列挙によるリソース存在性の漏洩を防ぐ。
      def set_owned_match_result
        @match_result = current_api_v1_user.match_results.find_by(id: params[:id])
      end

      def normalize_match_type
        return unless params.dig(:match_result, :match_type)

        params[:match_result][:match_type] = convert_match_type(params[:match_result][:match_type])
      end

      def match_results_params
        params.require(:match_result).permit(:user_id, :game_result_id, :date_and_time, :match_type, :my_team_id, :opponent_team_id, :my_team_score,
                                             :opponent_team_score, :batting_order, :defensive_position, :tournament_id, :memo, :inning_format)
      end
    end
  end
end
