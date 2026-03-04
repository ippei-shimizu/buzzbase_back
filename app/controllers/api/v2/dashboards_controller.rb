module Api
  module V2
    # ダッシュボード集約API
    #
    # ログインユーザーの直近試合結果・通算成績・グループ内ランキングを
    # 1リクエストで返却する。
    class DashboardsController < ApplicationController
      include Concerns::DashboardRankings

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

      # GET /api/v2/dashboard/batting_stats
      def batting_stats
        user = current_api_v1_user
        render json: build_batting_stats(user, year: params[:year], match_type: params[:match_type])
      end

      # GET /api/v2/dashboard/pitching_stats
      def pitching_stats
        user = current_api_v1_user
        render json: build_pitching_stats(user, year: params[:year], match_type: params[:match_type])
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
            batting_average: ba && serialize_batting(ba),
            pitching_result: pr && serialize_pitching(pr)
          }
        end
      end

      def serialize_batting(batting)
        { hit: batting.hit, at_bats: batting.at_bats, home_run: batting.home_run,
          runs_batted_in: batting.runs_batted_in }
      end

      def serialize_pitching(pitching)
        { innings_pitched: pitching.innings_pitched, run_allowed: pitching.run_allowed,
          earned_run: pitching.earned_run, strikeouts: pitching.strikeouts }
      end

      def build_batting_stats(user, year: nil, match_type: nil)
        aggregate = BattingAverage.filtered_aggregate_for_user(user.id, year:, match_type:).take
        calculated = BattingAverage.filtered_stats_for_user(user.id, year:, match_type:)

        return { aggregate: nil, calculated: nil } unless aggregate && calculated
        return { aggregate: nil, calculated: nil } if batting_all_zero?(aggregate)

        { aggregate: batting_aggregate_hash(aggregate), calculated: batting_calculated_hash(calculated) }
      end

      def batting_all_zero?(aggregate)
        [aggregate.hit, aggregate.two_base_hit, aggregate.three_base_hit,
         aggregate.home_run, aggregate.at_bats, aggregate.times_at_bat,
         aggregate.base_on_balls, aggregate.strike_out].all? { |v| v.to_i.zero? }
      end

      def batting_aggregate_hash(agg)
        { number_of_matches: agg.number_of_matches.to_i, hit: agg.hit.to_i,
          two_base_hit: agg.two_base_hit.to_i, three_base_hit: agg.three_base_hit.to_i,
          home_run: agg.home_run.to_i, total_bases: agg.total_bases.to_i,
          runs_batted_in: agg.runs_batted_in.to_i, run: agg.run.to_i,
          stealing_base: agg.stealing_base.to_i, caught_stealing: agg.caught_stealing.to_i,
          times_at_bat: agg.times_at_bat.to_i, at_bats: agg.at_bats.to_i,
          base_on_balls: agg.base_on_balls.to_i, hit_by_pitch: agg.hit_by_pitch.to_i,
          sacrifice_hit: agg.sacrifice_hit.to_i, sacrifice_fly: agg.sacrifice_fly.to_i,
          strike_out: agg.strike_out.to_i, error: agg.error.to_i }
      end

      def batting_calculated_hash(calc)
        { batting_average: calc[:batting_average], on_base_percentage: calc[:on_base_percentage],
          slugging_percentage: calc[:slugging_percentage], ops: calc[:ops],
          iso: calc[:iso], bb_per_k: calc[:bb_per_k], isod: calc[:isod] }
      end

      def build_pitching_stats(user, year: nil, match_type: nil)
        aggregate = PitchingResult.filtered_pitching_aggregate_for_user(user.id, year:, match_type:).take
        calculated = PitchingResult.filtered_pitching_stats_for_user(user.id, year:, match_type:)

        return { aggregate: nil, calculated: nil } unless aggregate && calculated
        return { aggregate: nil, calculated: nil } if pitching_all_zero?(aggregate)

        { aggregate: pitching_aggregate_hash(aggregate), calculated: pitching_calculated_hash(calculated) }
      end

      def pitching_all_zero?(aggregate)
        [aggregate.innings_pitched, aggregate.strikeouts, aggregate.hits_allowed,
         aggregate.base_on_balls, aggregate.earned_run, aggregate.win,
         aggregate.loss].all? { |v| v.to_f.zero? }
      end

      def pitching_aggregate_hash(agg)
        { number_of_appearances: agg.number_of_appearances.to_i, win: agg.win.to_i,
          loss: agg.loss.to_i, complete_games: agg.complete_games.to_i,
          shutouts: agg.shutouts.to_i, saves: agg.saves.to_i, hold: agg.hold.to_i,
          innings_pitched: agg.innings_pitched.to_f, hits_allowed: agg.hits_allowed.to_i,
          home_runs_hit: agg.home_runs_hit.to_i, strikeouts: agg.strikeouts.to_i,
          base_on_balls: agg.base_on_balls.to_i, hit_by_pitch: agg.hit_by_pitch.to_i,
          run_allowed: agg.run_allowed.to_i, earned_run: agg.earned_run.to_i }
      end

      def pitching_calculated_hash(calc)
        { era: calc[:era], win_percentage: calc[:win_percentage], whip: calc[:whip],
          k_per_nine: calc[:k_per_nine], bb_per_nine: calc[:bb_per_nine], k_bb: calc[:k_bb] }
      end

      def build_available_years(user)
        MatchResult.joins(:game_result)
                   .where(game_results: { user_id: user.id })
                   .select('EXTRACT(YEAR FROM date_and_time) AS year')
                   .distinct.order(Arel.sql('year DESC'))
                   .map { |r| r.year.to_i }
      end
    end
  end
end
