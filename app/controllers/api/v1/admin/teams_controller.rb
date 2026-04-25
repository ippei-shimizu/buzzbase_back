module Api
  module V1
    module Admin
      class TeamsController < Api::V1::Admin::BaseController
        before_action :set_team, only: %i[show destroy]

        DEFAULT_PER_PAGE = 20
        MAX_PER_PAGE = 100

        def index
          teams = Team.includes(:category, :prefecture, :user).order(created_at: :desc)
          total_count = teams.count
          page = [params[:page].to_i, 1].max
          per_page = params[:per_page].to_i.between?(1, MAX_PER_PAGE) ? params[:per_page].to_i : DEFAULT_PER_PAGE
          teams = teams.limit(per_page).offset((page - 1) * per_page)

          render json: {
            teams: ActiveModelSerializers::SerializableResource.new(
              teams,
              each_serializer: ::Admin::TeamSerializer
            ),
            pagination: {
              current_page: page,
              per_page:,
              total_count:,
              total_pages: (total_count.to_f / per_page).ceil
            }
          }
        end

        def show
          render json: {
            team: ::Admin::TeamDetailSerializer.new(@team)
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
