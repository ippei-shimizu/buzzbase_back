module Api
  module V2
    module Concerns
      # グループランキング構築ロジック
      module DashboardRankings
        extend ActiveSupport::Concern

        STAT_LABELS = {
          'batting_average' => '打率', 'home_run' => '本塁打',
          'runs_batted_in' => '打点', 'hit' => '安打',
          'stealing_base' => '盗塁', 'on_base_percentage' => '出塁率',
          'era' => '防御率', 'win' => '勝利',
          'saves' => 'セーブ', 'hold' => 'HP',
          'strikeouts' => '奪三振', 'win_percentage' => '勝率'
        }.freeze

        private

        def build_group_rankings(user)
          accepted_invitations = GroupInvitation.includes(:group)
                                                .where(user:, state: 'accepted')

          accepted_invitations.map do |invitation|
            group = invitation.group
            members = group.accepted_users
            member_ids = members.map(&:id)
            total_members = members.size

            # メンバー全員分の成績をバルク取得（N+1解消）
            batting_stats_by_user = BattingAverage.bulk_stats_for_users(member_ids)
            batting_aggregates_by_user = BattingAverage.aggregate_for_users(member_ids).index_by(&:user_id)
            pitching_stats_by_user = PitchingResult.bulk_pitching_stats_for_users(member_ids)
            pitching_aggregates_by_user = PitchingResult.pitching_aggregate_for_users(member_ids).index_by(&:user_id)

            preloaded = {
              batting_stats: batting_stats_by_user,
              batting_aggregates: batting_aggregates_by_user,
              pitching_stats: pitching_stats_by_user,
              pitching_aggregates: pitching_aggregates_by_user
            }

            {
              group_id: group.id,
              group_name: group.name,
              group_icon: group.icon.url,
              total_members:,
              batting_rankings: build_stat_rankings(group, user, members, GroupRankingSnapshot::BATTING_STAT_TYPES, preloaded),
              pitching_rankings: build_stat_rankings(group, user, members, GroupRankingSnapshot::PITCHING_STAT_TYPES, preloaded)
            }
          end
        end

        def build_stat_rankings(group, user, members, stat_types, preloaded)
          stat_types.map do |stat_type|
            current_rank = calculate_current_rank(user, members, stat_type, preloaded)
            previous = GroupRankingSnapshot.latest_for(
              group_id: group.id, user_id: user.id, stat_type:
            )

            change = (previous.rank - current_rank if current_rank && previous)

            {
              stat_type:,
              label: STAT_LABELS[stat_type],
              current_rank:,
              previous_rank: previous&.rank,
              change:,
              value: preloaded_value_for(user, stat_type, preloaded)
            }
          end
        end

        def calculate_current_rank(user, members, stat_type, preloaded)
          values = members.filter_map do |member|
            val = preloaded_value_for(member, stat_type, preloaded)
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

        def preloaded_value_for(user, stat_type, preloaded)
          if GroupRankingSnapshot::BATTING_STAT_TYPES.include?(stat_type)
            preloaded_batting_value(user, stat_type, preloaded)
          else
            preloaded_pitching_value(user, stat_type, preloaded)
          end
        end

        def preloaded_batting_value(user, stat_type, preloaded)
          case stat_type
          when 'batting_average', 'on_base_percentage'
            preloaded[:batting_stats][user.id]&.dig(stat_type.to_sym)
          else
            preloaded[:batting_aggregates][user.id]&.public_send(stat_type)&.to_i
          end
        end

        def preloaded_pitching_value(user, stat_type, preloaded)
          case stat_type
          when 'era', 'win_percentage'
            preloaded[:pitching_stats][user.id]&.dig(stat_type.to_sym)
          else
            preloaded[:pitching_aggregates][user.id]&.public_send(stat_type)&.to_i
          end
        end
      end
    end
  end
end
