module Api
  module V1
    module Admin
      class GroupsController < Api::V1::Admin::BaseController
        before_action :set_group, only: %i[destroy]

        def index
          groups = Group.includes(:group_users, :group_invitations).order(created_at: :desc)

          render json: {
            groups: ActiveModelSerializers::SerializableResource.new(
              groups,
              each_serializer: ::Admin::GroupSerializer
            )
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
