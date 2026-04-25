module Api
  module V1
    module Admin
      class GroupsController < Api::V1::Admin::BaseController
        before_action :set_group, only: %i[destroy]

        DEFAULT_PER_PAGE = 20
        MAX_PER_PAGE = 100

        def index
          groups = Group.includes(:group_users, :group_invitations).order(created_at: :desc)
          total_count = groups.count
          page = [params[:page].to_i, 1].max
          per_page = params[:per_page].to_i.between?(1, MAX_PER_PAGE) ? params[:per_page].to_i : DEFAULT_PER_PAGE
          groups = groups.limit(per_page).offset((page - 1) * per_page)

          render json: {
            groups: ActiveModelSerializers::SerializableResource.new(
              groups,
              each_serializer: ::Admin::GroupSerializer
            ),
            pagination: {
              current_page: page,
              per_page:,
              total_count:,
              total_pages: (total_count.to_f / per_page).ceil
            }
          }
        end

        def destroy
          return render json: { errors: ['メンバーが所属しているため削除できません'] }, status: :unprocessable_entity if @group.group_users.exists?

          @group.destroy!
          render json: { message: 'グループを削除しました' }
        end

        private

        def set_group
          @group = Group.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { errors: ['グループが見つかりません'] }, status: :not_found
        end
      end
    end
  end
end
