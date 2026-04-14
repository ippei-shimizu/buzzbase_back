module Api
  module V1
    class TournamentsController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[create update user_tournaments]
      before_action :set_tournament, only: %i[show update]

      def index
        @tournaments = Tournament.all
        render json: @tournaments
      end

      # GET /api/v1/tournaments/user_tournaments
      # 指定ユーザー（またはログインユーザー）の試合に紐づく大会のみ返す
      def user_tournaments
        user = params[:user_id].present? ? User.find_by(id: params[:user_id]) : current_api_v1_user
        return render json: { error: 'ユーザーが存在しません' }, status: :not_found unless user
        unless user == current_api_v1_user || user.profile_visible_to?(current_api_v1_user)
          return render json: { error: 'このアカウントは非公開です' }, status: :forbidden
        end

        tournaments = Tournament.joins(:match_results)
                                .where(match_results: { user_id: user.id })
                                .distinct
                                .order(:name)
        render json: tournaments
      end

      def show
        if @tournament
          render json: { name: @tournament.name }
        else
          render json: { error: '大会名が見つかりません。' }, status: :not_found
        end
      end

      def create
        tournament = Tournament.new(tournament_params)
        if tournament.save
          render json: tournament, status: :created
        else
          render json: tournament.errors, status: :unprocessable_entity
        end
      end

      def update
        if @tournament.update(tournament_params)
          render json: @tournament, status: :ok
        else
          render json: @tournament.errors, status: :unprocessable_entity
        end
      end

      private

      def set_tournament
        @tournament = Tournament.find(params[:id])
      end

      def tournament_params
        params.require(:tournament).permit(:name)
      end
    end
  end
end
