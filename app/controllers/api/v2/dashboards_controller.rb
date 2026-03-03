module Api
  module V2
    # ダッシュボード集約API
    #
    # ログインユーザーの直近試合結果・通算成績・グループ内ランキングを
    # 1リクエストで返却する。
    class DashboardsController < ApplicationController
      before_action :authenticate_api_v1_user!

      # GET /api/v2/dashboard
      def show
        user = current_api_v1_user
        year = params[:year]
        match_type = params[:match_type]

        render json: {
          recent_game_results: build_recent_game_results(user),
          batting_stats: build_batting_stats(user, year:, match_type:),
          pitching_stats: build_pitching_stats(user, year:, match_type:),
          group_rankings: build_group_rankings(user),
          available_years: build_available_years(user)
        }
      end

      private

      def build_recent_game_results(user)
        game_results = GameResult.v2_game_associated_data_user(user).limit(3)

        game_results.map do |gr|
          mr = gr.match_result
          ba = gr.batting_average
          pr = gr.pitching_result

          {
            id: gr.id,
            date: mr&.date_and_time,
            opponent_team_name: mr&.opponent_team&.name,
            my_team_score: mr&.my_team_score,
            opponent_team_score: mr&.opponent_team_score,
            match_type: mr&.match_type,
            batting_average: if ba
                               {
                                 hit: ba.hit,
                                 at_bats: ba.at_bats,
                                 home_run: ba.home_run,
                                 runs_batted_in: ba.runs_batted_in
                               }
                             end,
            pitching_result: if pr
                               {
                                 innings_pitched: pr.innings_pitched,
                                 run_allowed: pr.run_allowed,
                                 earned_run: pr.earned_run,
                                 strikeouts: pr.strikeouts
                               }
                             end
          }
        end
      end

      def build_batting_stats(user, year: nil, match_type: nil)
        aggregate = BattingAverage.filtered_aggregate_for_user(user.id, year:, match_type:).take
        calculated = BattingAverage.filtered_stats_for_user(user.id, year:, match_type:)

        return { aggregate: nil, calculated: nil } unless aggregate && calculated

        # 全値0 = 実質未記録なのでnilとして扱う
        if [aggregate.hit, aggregate.two_base_hit, aggregate.three_base_hit,
            aggregate.home_run, aggregate.at_bats, aggregate.times_at_bat,
            aggregate.base_on_balls, aggregate.strike_out].all? { |v| v.to_i.zero? }
          return { aggregate: nil, calculated: nil }
        end

        {
          aggregate: {
            number_of_matches: aggregate.number_of_matches.to_i,
            hit: aggregate.hit.to_i,
            two_base_hit: aggregate.two_base_hit.to_i,
            three_base_hit: aggregate.three_base_hit.to_i,
            home_run: aggregate.home_run.to_i,
            total_bases: aggregate.total_bases.to_i,
            runs_batted_in: aggregate.runs_batted_in.to_i,
            run: aggregate.run.to_i,
            stealing_base: aggregate.stealing_base.to_i,
            caught_stealing: aggregate.caught_stealing.to_i,
            times_at_bat: aggregate.times_at_bat.to_i,
            at_bats: aggregate.at_bats.to_i,
            base_on_balls: aggregate.base_on_balls.to_i,
            hit_by_pitch: aggregate.hit_by_pitch.to_i,
            sacrifice_hit: aggregate.sacrifice_hit.to_i,
            sacrifice_fly: aggregate.sacrifice_fly.to_i,
            strike_out: aggregate.strike_out.to_i,
            error: aggregate.error.to_i
          },
          calculated: {
            batting_average: calculated[:batting_average],
            on_base_percentage: calculated[:on_base_percentage],
            slugging_percentage: calculated[:slugging_percentage],
            ops: calculated[:ops],
            iso: calculated[:iso],
            bb_per_k: calculated[:bb_per_k],
            isod: calculated[:isod]
          }
        }
      end

      def build_pitching_stats(user, year: nil, match_type: nil)
        aggregate = PitchingResult.filtered_pitching_aggregate_for_user(user.id, year:, match_type:).take
        calculated = PitchingResult.filtered_pitching_stats_for_user(user.id, year:, match_type:)

        return { aggregate: nil, calculated: nil } unless aggregate && calculated

        # 全値0 = 実質未記録なのでnilとして扱う
        if [aggregate.innings_pitched, aggregate.strikeouts, aggregate.hits_allowed,
            aggregate.base_on_balls, aggregate.earned_run, aggregate.win,
            aggregate.loss].all? { |v| v.to_f.zero? }
          return { aggregate: nil, calculated: nil }
        end

        {
          aggregate: {
            number_of_appearances: aggregate.number_of_appearances.to_i,
            win: aggregate.win.to_i,
            loss: aggregate.loss.to_i,
            complete_games: aggregate.complete_games.to_i,
            shutouts: aggregate.shutouts.to_i,
            saves: aggregate.saves.to_i,
            hold: aggregate.hold.to_i,
            innings_pitched: aggregate.innings_pitched.to_f,
            hits_allowed: aggregate.hits_allowed.to_i,
            home_runs_hit: aggregate.home_runs_hit.to_i,
            strikeouts: aggregate.strikeouts.to_i,
            base_on_balls: aggregate.base_on_balls.to_i,
            hit_by_pitch: aggregate.hit_by_pitch.to_i,
            run_allowed: aggregate.run_allowed.to_i,
            earned_run: aggregate.earned_run.to_i
          },
          calculated: {
            era: calculated[:era],
            win_percentage: calculated[:win_percentage],
            whip: calculated[:whip],
            k_per_nine: calculated[:k_per_nine],
            bb_per_nine: calculated[:bb_per_nine],
            k_bb: calculated[:k_bb]
          }
        }
      end

      def build_available_years(user)
        MatchResult.joins(:game_result)
                   .where(game_results: { user_id: user.id })
                   .select('EXTRACT(YEAR FROM date_and_time) AS year')
                   .distinct.order('year DESC')
                   .map { |r| r.year.to_i }
      end

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
        stat_labels = {
          'batting_average' => '打率',
          'home_run' => '本塁打',
          'runs_batted_in' => '打点',
          'hit' => '安打',
          'stealing_base' => '盗塁',
          'on_base_percentage' => '出塁率',
          'era' => '防御率',
          'win' => '勝利',
          'saves' => 'セーブ',
          'hold' => 'HP',
          'strikeouts' => '奪三振',
          'win_percentage' => '勝率'
        }

        stat_types.map do |stat_type|
          current_rank = calculate_current_rank(group, user, members, stat_type)
          previous = GroupRankingSnapshot.latest_for(
            group_id: group.id, user_id: user.id, stat_type:
          )

          change = (previous.rank - current_rank if current_rank && previous)

          {
            stat_type:,
            label: stat_labels[stat_type],
            current_rank:,
            previous_rank: previous&.rank,
            change:,
            value: current_value_for(user, stat_type)
          }
        end
      end

      def calculate_current_rank(_group, user, members, stat_type)
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
        case stat_type
        when 'batting_average', 'on_base_percentage'
          stats = BattingAverage.stats_for_user(user.id)
          stats&.dig(stat_type.to_sym)
        when 'home_run', 'runs_batted_in', 'hit', 'stealing_base'
          aggregate = BattingAverage.aggregate_for_user(user.id).take
          return nil unless aggregate

          aggregate.public_send(stat_type).to_i
        when 'era', 'win_percentage'
          stats = PitchingResult.pitching_stats_for_user(user.id)
          stats&.dig(stat_type.to_sym)
        when 'win', 'saves', 'hold', 'strikeouts'
          aggregate = PitchingResult.pitching_aggregate_for_user(user.id).take
          return nil unless aggregate

          aggregate.public_send(stat_type).to_i
        end
      end
    end
  end
end
