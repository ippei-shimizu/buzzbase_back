module Api
  module V1
    class GroupInvitationsController < ApplicationController
      before_action :authenticate_api_v1_user!

      def accept_invitation
        group_id = params[:id]
        invitation = GroupInvitation.find_by(group_id:, user_id: current_api_v1_user.id)
        if invitation.nil?
          render json: { error: '招待状況が見つかりません' }, status: :not_found
        elsif !current_api_v1_user.can_create_or_join_group?
          render json: { error: 'group_limit_exceeded',
                         message: 'Pro プランでグループを無制限に作成・参加できます' }, status: :forbidden
        else
          invitation.accepted!
          render json: { success: true }
        end
      end

      def declined_invitation
        group_id = params[:id]
        invitation = GroupInvitation.find_by(group_id:, user_id: current_api_v1_user.id)
        if invitation
          invitation.declined!
          render json: { success: true }
        else
          render json: { error: '招待状況が見つかりません' }, status: :not_found
        end
      end
    end
  end
end
