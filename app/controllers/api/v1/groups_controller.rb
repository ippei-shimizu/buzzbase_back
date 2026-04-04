module Api
  module V1
    class GroupsController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[create update destroy]

      def index
        accepted_group_ids = GroupInvitation.where(user_id: current_api_v1_user.id, state: 'accepted').pluck(:group_id)
        groups = Group.where(id: accepted_group_ids)

        render json: groups.as_json(only: %i[id name icon], include: { group_users: { only: %i[user_id group_id] } })
      end

      def show
        group = Group.find(params[:id])

        return render json: { error: 'アクセス権限がありません' }, status: :forbidden unless group.group_invitations.exists?(user: current_api_v1_user,
                                                                                                                 state: 'accepted')

        accepted_users = group.accepted_users
        stats = build_group_stats(accepted_users)

        render json: { group:, accepted_users:, **stats }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'グループは存在しません' }, status: :not_found
      end

      def create
        group = current_api_v1_user.groups.build(group_params)
        if group.save
          group.users << current_api_v1_user
          group.group_invitations.create(user: current_api_v1_user, state: 'accepted', sent_at: Time.current)
          invite_users(group, invite_user_ids_params)
          render json: group, status: :created
        else
          render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        group = Group.find(params[:id])
        invited_users = []
        ActiveRecord::Base.transaction do
          group.update!(group_params) if params[:group]
          if params[:invite_user_ids]
            user_ids = params[:invite_user_ids].map(&:to_i)
            invited_users = group.update_users_by_ids(user_ids)
          end
        end

        notify_invited_users(invited_users, group)
        render json: group, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update_group_info
        group = Group.find(params[:id])
        return render json: { error: 'アクセス権限がありません' }, status: :forbidden unless group.group_invitations.exists?(user: current_api_v1_user,
                                                                                                                 state: 'accepted')

        if group.update(group_params)
          render json: group, status: :ok
        else
          render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show_group_user
        group = Group.find(params[:id])

        return render json: { error: 'アクセス権限がありません' }, status: :forbidden unless group.group_invitations.exists?(user: current_api_v1_user,
                                                                                                                 state: 'accepted')

        accepted_users = group.accepted_users
        group_creator_id = GroupUser.find_by(group_id: group.id)&.user_id
        render json: { group:, accepted_users:, group_creator_id: }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'グループは存在しません' }, status: :not_found
      end

      def invite_members
        group = Group.find(params[:id])
        return render json: { error: 'アクセス権限がありません' }, status: :forbidden unless group.group_invitations.exists?(user: current_api_v1_user,
                                                                                                                 state: 'accepted')

        user_ids = invite_user_ids_params.map(&:to_i)
        invite_users(group, user_ids)

        render json: { message: '招待を送信しました' }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'グループは存在しません' }, status: :not_found
      end

      def destroy
        group = Group.find(params[:id])
        return render json: { error: '削除権限がありません' }, status: :forbidden unless GroupUser.exists?(user_id: current_api_v1_user.id,
                                                                                                 group_id: group.id)

        group.destroy
        render json: { message: 'グループが削除されました' }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'グループは存在しません' }, status: :not_found
      end

      private

      def build_group_stats(accepted_users)
        year = params[:year]
        match_type = params[:match_type]

        batting_averages = accepted_users.map { |u| BattingAverage.filtered_aggregate_for_user(u.id, year:, match_type:) }
        batting_stats = accepted_users.map { |u| BattingAverage.stats_for_user(u.id, year:, match_type:) }
        pitching_aggregate = accepted_users.map { |u| PitchingResult.filtered_pitching_aggregate_for_user(u.id, year:, match_type:) }
        pitching_stats = accepted_users.map { |u| PitchingResult.pitching_stats_for_user(u.id, year:, match_type:) }
        available_years = fetch_available_years(accepted_users)

        { batting_averages:, batting_stats:, pitching_aggregate:, pitching_stats:, available_years: }
      end

      def fetch_available_years(accepted_users)
        user_ids = accepted_users.map(&:id)
        MatchResult.joins(:game_result)
                   .where(game_results: { user_id: user_ids })
                   .select('EXTRACT(YEAR FROM date_and_time) AS year')
                   .distinct.order(Arel.sql('year DESC'))
                   .map { |r| r.year.to_i }
      end

      def group_params
        params.require(:group).permit(:name, :icon)
      end

      def invite_user_ids_params
        params[:invite_user_ids] || []
      end

      def notify_invited_users(users, group)
        users.each do |user|
          notification = Notification.create!(actor: current_api_v1_user, event_type: 'group_invitation', event_id: group.id)
          UserNotification.create!(user_id: user.id, notification_id: notification.id)
          PushNotificationService.send_to_user(user, title: 'BUZZ BASE', body: "#{current_api_v1_user.name}さんからグループに招待されました")
        end
      end

      def invite_users(group, user_ids)
        user_ids.each do |user_id|
          user = User.find_by(id: user_id)
          next unless user && current_api_v1_user.following.include?(user)

          next if group.group_invitations.exists?(user:, state: 'accepted')

          invitation = group.group_invitations.find_or_initialize_by(user:)
          next unless invitation.new_record?

          invitation.state = 'pending'
          invitation.sent_at = Time.current
          invitation.save!

          notification = Notification.create!(
            actor: current_api_v1_user,
            event_type: 'group_invitation',
            event_id: group.id
          )
          UserNotification.create!(
            user_id: user.id,
            notification_id: notification.id
          )
          PushNotificationService.send_to_user(
            user,
            title: 'BUZZ BASE',
            body: "#{current_api_v1_user.name}さんからグループに招待されました"
          )
        end
      end
    end
  end
end
