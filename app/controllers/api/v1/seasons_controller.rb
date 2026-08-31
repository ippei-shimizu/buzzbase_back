module Api
  module V1
    class SeasonsController < ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :set_season, only: %i[update destroy]

      def index
        user = if params[:user_id].present?
                 User.find(params[:user_id])
               else
                 current_api_v1_user
               end
        return render json: { error: 'このアカウントは非公開です' }, status: :forbidden unless user.profile_visible_to?(current_api_v1_user)

        seasons = user.seasons.left_joins(:game_results)
                      .select('seasons.*, COUNT(game_results.id) AS game_results_count')
                      .group('seasons.id')
                      .order(created_at: :desc)
        render json: seasons.map { |s| s.as_json.merge(game_results_count: s.game_results_count) }
      end

      # 同名シーズンが既にあれば作成せず既存を返す（冪等）。
      # 試合登録でシーズン名を手入力したときに一意性違反で登録フロー全体が落ちるのを防ぐ。
      def create
        season = Season.find_or_create_for!(current_api_v1_user, season_params[:name])
        render json: season, status: :created
      rescue ActiveRecord::RecordInvalid => e
        # ApplicationController の rescue_from に任せると空入力のたびに Sentry へ送られるため、ここで返す。
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        if @season.update(season_params)
          render json: @season
        else
          render json: { errors: @season.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        if @season.destroy
          render json: { message: 'シーズンを削除しました' }, status: :ok
        else
          render json: { errors: @season.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_season
        @season = current_api_v1_user.seasons.find(params[:id])
      end

      def season_params
        params.require(:season).permit(:name)
      end
    end
  end
end
