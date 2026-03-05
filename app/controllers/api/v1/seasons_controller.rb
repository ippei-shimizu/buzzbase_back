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

        seasons = user.seasons.order(created_at: :desc)
        render json: seasons
      end

      def create
        season = current_api_v1_user.seasons.build(season_params)
        if season.save
          render json: season, status: :created
        else
          render json: { errors: season.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @season.update(season_params)
          render json: @season
        else
          render json: { errors: @season.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @season.destroy
        render json: { message: 'シーズンを削除しました' }, status: :ok
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
