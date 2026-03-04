module Api
  module V2
    module Concerns
      # グループランキング構築ロジック
      module DashboardRankings
        extend ActiveSupport::Concern

        private

        def build_group_rankings(user)
          accepted_invitations = GroupInvitation.includes(:group)
                                                .where(user:, state: 'accepted')

          accepted_invitations.map do |invitation|
            group = invitation.group
            members = group.accepted_users
            total_members = members.size

            {
              group_id: group.id,
              group_name: group.name,
              group_icon: group.icon.url,
              total_members:,
              batting_rankings: build_stat_rankings(group, user, members, GroupRankingSnapshot::BATTING_STAT_TYPES),
              pitching_rankings: build_stat_rankings(group, user, members, GroupRankingSnapshot::PITCHING_STAT_TYPES)
            }
          end
        end

        def build_stat_rankings(group, user, members, stat_types)
          stat_types.map do |stat_type|
            current_rank = calculate_current_rank(user, members, stat_type)
            previous = GroupRankingSnapshot.latest_for(
              group_id: group.id, user_id: user.id, stat_type:
            )

            change = (previous.rank - current_rank if current_rank && previous)

            {
              stat_type:,
              label: stat_label_for(stat_type),
              current_rank:,
              previous_rank: previous&.rank,
              change:,
              value: current_value_for(user, stat_type)
            }
          end
        end

        def stat_label_for(stat_type)
          {
            'batting_average' => '打率', 'home_run' => '本塁打',
            'runs_batted_in' => '打点', 'hit' => '安打',
            'stealing_base' => '盗塁', 'on_base_percentage' => '出塁率',
            'era' => '防御率', 'win' => '勝利',
            'saves' => 'セーブ', 'hold' => 'HP',
            'strikeouts' => '奪三振', 'win_percentage' => '勝率'
          }[stat_type]
        end

        def calculate_current_rank(user, members, stat_type)
          values = members.filter_map do |member|
            val = current_value_for(member, stat_type)
            next unless val

            { user_id: member.id, value: val }
          end

          return nil if values.empty?

          sorted = if GroupRankingSnapshotService::ASC_STAT_TYPES.include?(stat_type)
                     values.sort_by { |e| e[:value] }
                   else
                     values.sort_by { |e| -e[:value] }
                   end

          rank_entry = sorted.index { |e| e[:user_id] == user.id }
          rank_entry ? rank_entry + 1 : nil
        end

        def current_value_for(user, stat_type)
          batting_stat_value(user, stat_type) || pitching_stat_value(user, stat_type)
        end

        def batting_stat_value(user, stat_type)
          case stat_type
          when 'batting_average', 'on_base_percentage'
            BattingAverage.stats_for_user(user.id)&.dig(stat_type.to_sym)
          when 'home_run', 'runs_batted_in', 'hit', 'stealing_base'
            BattingAverage.aggregate_for_user(user.id).take&.public_send(stat_type)&.to_i
          end
        end

        def pitching_stat_value(user, stat_type)
          case stat_type
          when 'era', 'win_percentage'
            PitchingResult.pitching_stats_for_user(user.id)&.dig(stat_type.to_sym)
          when 'win', 'saves', 'hold', 'strikeouts'
            PitchingResult.pitching_aggregate_for_user(user.id).take&.public_send(stat_type)&.to_i
          end
        end
      end
    end
  end
end
