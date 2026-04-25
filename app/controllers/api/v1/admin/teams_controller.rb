module Api
  module V1
    module Admin
      class TeamsController < Api::V1::Admin::BaseController
        before_action :set_team, only: %i[destroy]

        def index
          teams = Team.includes(:category, :prefecture, :user).order(created_at: :desc)

          render json: {
            teams: ActiveModelSerializers::SerializableResource.new(
              teams,
              each_serializer: ::Admin::TeamSerializer
            )
          }
        end

        def destroy
          if MatchResult.where(my_team_id: @team.id).or(MatchResult.where(opponent_team_id: @team.id)).exists?
            return render json: { errors: ['試合結果が紐づいているため削除できません'] }, status: :unprocessable_entity
          end

          @team.destroy!
          render json: { message: 'チームを削除しました' }
        end

        private

        def set_team
          @team = Team.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { errors: ['チームが見つかりません'] }, status: :not_found
        end
      end
    end
  end
end
