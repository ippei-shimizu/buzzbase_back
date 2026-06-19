# frozen_string_literal: true

require 'rails_helper'

# Stats::BattingFormulas SSoT 化後、マイページ / stats タブ headline /
# additional / trend / table の打率・出塁率・長打率・OPS が完全に
# 一致することを保証する retention test。
#
# 過去に式が散らばっていた状態では「stats タブだけ過少表示」や
# 「stats タブだけ通算 OPS が違う」といった乖離が発生していた。本 spec は
# その再発を構造的に防ぐ（どこか 1 つでも独自再計算に戻ったら ROUND-TRIP で
# 必ず差分が出る）。
RSpec.describe 'Batting stats SSoT consistency across aggregators', type: :service do # rubocop:disable RSpec/DescribeClass
  let(:user) { create(:user) }

  def create_game_with_batting(date:, hit:, at_bats:, two_base_hit: 0, three_base_hit: 0, # rubocop:disable Metrics/ParameterLists
                               home_run: 0, base_on_balls: 0, hit_by_pitch: 0,
                               sacrifice_fly: 0, strike_out: 0)
    game = create(:game_result, user:)
    game.match_result.update!(date_and_time: Time.zone.parse("#{date} 12:00:00"), match_type: 'regular')
    total_bases = hit + (two_base_hit * 2) + (three_base_hit * 3) + (home_run * 4)
    create(:batting_average, game_result: game, user:,
                             hit:, at_bats:, total_bases:,
                             two_base_hit:, three_base_hit:, home_run:,
                             base_on_balls:, hit_by_pitch:, sacrifice_fly:,
                             times_at_bat: at_bats + base_on_balls + hit_by_pitch + sacrifice_fly,
                             strike_out:, sacrifice_hit: 0)
  end

  context 'with mixed singles / doubles / triples / home runs in a single year' do
    before do
      create_game_with_batting(date: '2026-04-01', hit: 1, at_bats: 4, two_base_hit: 1, base_on_balls: 1, strike_out: 1)
      create_game_with_batting(date: '2026-04-15', hit: 1, at_bats: 3, home_run: 1, strike_out: 1)
      create_game_with_batting(date: '2026-04-30', hit: 1, at_bats: 5)
    end

    # 通算: AB=12, hit=3, 2B=1, 3B=0, HR=1, total_hits=5, TB=3+2+0+4=9, BB=1, HBP=0, SF=0
    # 打率 = 5/12 = .417, OBP = 6/13 = .462, SLG = 9/12 = .750, OPS = 1.212

    it '全集計レイヤーで打率 / OBP / SLG / OPS が完全一致する' do # rubocop:disable RSpec/ExampleLength
      mypage     = BattingAverage.stats_for_user(user.id)
      headline   = Stats::HeadlineStatsAggregator.new(user_id: user.id).call
      additional = Stats::AdditionalStatsAggregator.new(user_id: user.id).call
      trend_last = Stats::BattingTrendAggregator.new(user_id: user.id, granularity: 'game').call[:points].last
      table_row  = Stats::BattingStatsTableService.new(user_id: user.id, mode: :yearly).call.first

      aggregate_failures do
        expect(headline[:batting_average]).to eq(mypage[:batting_average])
        expect(trend_last[:batting_average]).to eq(mypage[:batting_average])
        expect(table_row[:batting_average]).to eq(mypage[:batting_average])
        expect(headline[:on_base_percentage]).to eq(mypage[:on_base_percentage])
        expect(trend_last[:on_base_percentage]).to eq(mypage[:on_base_percentage])
        expect(headline[:slugging_percentage]).to eq(mypage[:slugging_percentage])
        expect(trend_last[:slugging_percentage]).to eq(mypage[:slugging_percentage])
        expect(table_row[:slugging_percentage]).to eq(mypage[:slugging_percentage])
        expect(headline[:ops]).to eq(mypage[:ops])
        expect(trend_last[:ops]).to eq(mypage[:ops])
        expect(table_row[:ops]).to eq(mypage[:ops])
        expect(additional[:iso]).to eq(mypage[:iso])
        expect(table_row[:iso]).to eq(mypage[:iso])
        expect(additional[:isod]).to eq(mypage[:isod])
      end
    end

    it 'NPB 公式式が要求する具体値と一致する（既存挙動の固定）' do
      mypage = BattingAverage.stats_for_user(user.id)
      expected_avg = (5.0 / 12).round(3)
      expected_obp = (6.0 / 13).round(3)
      expected_slg = (9.0 / 12).round(3)
      expected_ops = (expected_obp + expected_slg).round(3)

      aggregate_failures do
        expect(mypage[:batting_average]).to eq(expected_avg)
        expect(mypage[:on_base_percentage]).to eq(expected_obp)
        expect(mypage[:slugging_percentage]).to eq(expected_slg)
        expect(mypage[:ops]).to eq(expected_ops)
      end
    end
  end

  context 'with zero at-bats (only walks / hit-by-pitch)' do
    before do
      create_game_with_batting(date: '2026-05-01', hit: 0, at_bats: 0, base_on_balls: 2, hit_by_pitch: 1)
    end

    it 'ゼロ除算ガードで全レイヤーが NaN / Infinity を返さない' do
      mypage = BattingAverage.stats_for_user(user.id)
      headline = Stats::HeadlineStatsAggregator.new(user_id: user.id).call

      aggregate_failures do
        expect(mypage[:batting_average]).to eq(0.0)
        expect(headline[:batting_average]).to eq(0.0)
        expect(mypage[:slugging_percentage]).to eq(0.0)
        expect(headline[:slugging_percentage]).to eq(0.0)
        # OBP は AB=0 でも BB / HBP があれば 1.0 になる仕様
        expect(headline[:on_base_percentage]).to eq(1.0)
      end
    end
  end
end
