module Api
  module V1
    class BattingAveragesController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[create update search current_batting_average_search]
      before_action :set_batting_average, only: %i[update]

      def index
        batting_averages = BattingAverage.includes(:user, :game_result)
        render json: batting_averages
      end

      def create
        batting_average = BattingAverage.new(batting_average_params)
        if batting_average.save
          render json: batting_average, status: :created
        else
          render json: batting_average.errors, status: :unprocessable_entity
        end
      end

      def update
        if @batting_average.update(batting_average_params)
          render json: @batting_average
        else
          render json: @batting_average.errors, status: :unprocessable_entity
        end
      end

      def search
        @batting_average = BattingAverage.find_by(game_result_id: params[:game_result_id], user_id: params[:user_id])
        if @batting_average
          render json: @batting_average
        else
          render json: { message: 'No matching record found' }, status: :not_found
        end
      end

      def current_batting_average_search
        if params[:game_result_id].present?
          batting_average = BattingAverage.where(game_result_id: params[:game_result_id], user_id: current_api_v1_user.id)
          if batting_average.present?
            render json: batting_average
          else
            render json: []
          end
        else
          render json: []
        end
      end

      def user_batting_average_search
        if params[:game_result_id].present?
          game_result = GameResult.find_by(id: params[:game_result_id])
          if game_result
            user = game_result.user
            return render json: { error: 'このアカウントは非公開です' }, status: :forbidden unless user.profile_visible_to?(current_api_v1_user)
          end
          batting_average = BattingAverage.where(game_result_id: params[:game_result_id])
          if batting_average.present?
            render json: batting_average
          else
            render json: []
          end
        else
          render json: []
        end
      end

      def personal_batting_average
        user_id = params[:user_id]
        year = params[:year]
        match_type = convert_match_type(params[:match_type])
        season_id = params[:season_id]
        aggregated_data = if year.present? || match_type.present? || season_id.present?
                            BattingAverage.filtered_aggregate_for_user(user_id, year:, match_type:, season_id:)
                          else
                            BattingAverage.aggregate_for_user(user_id)
                          end
        render json: aggregated_data
      end

      def personal_batting_stats
        user_id = params[:user_id]
        year = params[:year]
        match_type = convert_match_type(params[:match_type])
        season_id = params[:season_id]
        batting_stats = BattingAverage.stats_for_user(user_id, year:, match_type:, season_id:)
        if batting_stats.present?
          render json: batting_stats
        else
          render json: { error: 'Batting average not found for current user' }, status: :not_found
        end
      end

      private

      def set_batting_average
        @batting_average = BattingAverage.find(params[:id])
      end

      def convert_match_type(match_type)
        case match_type
        when '公式戦' then 'regular'
        when 'オープン戦' then 'open'
        else match_type
        end
      end

      def batting_average_params
        params.require(:batting_average).permit(
          :game_result_id, :user_id, :plate_appearances, :times_at_bat, :hit,
          :two_base_hit, :three_base_hit, :home_run, :total_bases, :runs_batted_in,
          :run, :strike_out, :base_on_balls, :hit_by_pitch, :sacrifice_hit, :sacrifice_fly,
          :stealing_base, :caught_stealing, :error, :at_bats
        )
      end
    end
  end
end
