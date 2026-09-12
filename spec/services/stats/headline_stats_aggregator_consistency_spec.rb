# frozen_string_literal: true

require 'rails_helper'

# stats タブの主要スタッツ (Stats::HeadlineStatsAggregator) と
# マイページ / ダッシュボード / ランキングで使う BattingAverage.stats_for_user の
# 打率 / OBP / SLG / OPS が一致することを保証する retention test。
#
# 以前は HeadlineStats が SUM(hit) を「総安打」と解釈する一方、本番の
# batting_averages.hit は「単打のみ」を保持する semantics になっており、
# stats タブだけ過少表示される乖離が発生していた (#387 revert で判明)。
# 集計式を Approach C で揃え直した後、両系統が常に同じ値を返すことを
# 保護する。
RSpec.describe 'HeadlineStatsAggregator consistency with BattingAverage.stats_for_user', type: :service do # rubocop:disable RSpec/DescribeClass
  let(:user) { create(:user) }

  def create_game_with_batting(date:, hit:, at_bats:, two_base_hit: 0, three_base_hit: 0, # rubocop:disable Metrics/ParameterLists
                               home_run: 0, base_on_balls: 0, hit_by_pitch: 0,
                               sacrifice_fly: 0)
    game = create(:game_result, user:)
    game.match_result.update!(date_and_time: Time.zone.parse(date), match_type: 'regular')
    # `hit` は単打のみを保持する semantics。塁打 (TB) は単打×1 + 2B×2 + 3B×3 + HR×4。
    total_bases = hit + (two_base_hit * 2) + (three_base_hit * 3) + (home_run * 4)
    create(:batting_average, game_result: game, user:,
                             hit:, at_bats:, total_bases:,
                             two_base_hit:, three_base_hit:, home_run:,
                             base_on_balls:, hit_by_pitch:, sacrifice_fly:,
                             times_at_bat: at_bats + base_on_balls + hit_by_pitch + sacrifice_fly,
                             strike_out: 0, sacrifice_hit: 0)
  end

  context 'with mixed singles, doubles, triples, home runs across games' do
    before do
      # 試合 1: 単打 1 + 2B 1 + 三振 1 + ゴロ 1 + BB 1 → AB=4 hit=1 2B=1
      create_game_with_batting(date: '2026-04-01', hit: 1, at_bats: 4, two_base_hit: 1, base_on_balls: 1)
      # 試合 2: 単打 1 + HR 1 + 三振 1 → AB=3 hit=1 HR=1
      create_game_with_batting(date: '2026-04-15', hit: 1, at_bats: 3, home_run: 1)
      # 試合 3: 単打 1 + アウト 4 → AB=5 hit=1
      create_game_with_batting(date: '2026-04-30', hit: 1, at_bats: 5)
    end

    # 通算: AB=12, hit=3, 2B=1, 3B=0, HR=1, total_hits=5, TB=3+2+0+4=9, BB=1, HBP=0, SF=0
    # 打率 = 5/12 = .417
    # OBP = (5+1+0)/(12+1+0+0) = 6/13 = .462
    # SLG = 9/12 = .750
    # OPS = .462 + .750 = 1.212

    it 'マイページ stats_for_user と stats タブ HeadlineStatsAggregator が同じ打率を返す' do
      mypage = BattingAverage.stats_for_user(user.id)
      headline = Stats::HeadlineStatsAggregator.new(user_id: user.id).call

      aggregate_failures do
        expect(mypage[:batting_average]).to eq(headline[:batting_average])
        expect(mypage[:on_base_percentage]).to eq(headline[:on_base_percentage])
        expect(mypage[:slugging_percentage]).to eq(headline[:slugging_percentage])
        expect(mypage[:ops]).to eq(headline[:ops])
        # マイページの total_hits と stats タブの hit が NPB 標準で一致する（= 全安打）
        expect(mypage[:total_hits]).to eq(headline[:hit])
      end
    end

    it 'aggregate_for_user が返す hit も全安打で一致する（ダッシュボード / ランキング表示の整合性）' do
      aggregate = BattingAverage.aggregate_for_user(user.id).take
      headline = Stats::HeadlineStatsAggregator.new(user_id: user.id).call

      expect(aggregate.hit.to_i).to eq(headline[:hit])
    end

    it '両系統が NPB 公式式と一致する具体値を返す' do
      mypage = BattingAverage.stats_for_user(user.id)
      headline = Stats::HeadlineStatsAggregator.new(user_id: user.id).call
      expected_avg = (5.0 / 12).round(3)
      expected_obp = (6.0 / 13).round(3)
      expected_slg = (9.0 / 12).round(3)

      aggregate_failures do
        expect(mypage[:batting_average]).to eq(expected_avg)
        expect(headline[:batting_average]).to eq(expected_avg)
        expect(mypage[:on_base_percentage]).to eq(expected_obp)
        expect(headline[:on_base_percentage]).to eq(expected_obp)
        expect(mypage[:slugging_percentage]).to eq(expected_slg)
        expect(headline[:slugging_percentage]).to eq(expected_slg)
        expect(mypage[:ops]).to eq((expected_obp + expected_slg).round(3))
        expect(headline[:ops]).to eq((expected_obp + expected_slg).round(3))
      end
    end
  end

  context 'with year filter' do
    before do
      create_game_with_batting(date: '2025-09-30', hit: 1, at_bats: 4, two_base_hit: 1)
      create_game_with_batting(date: '2026-04-01', hit: 2, at_bats: 6, home_run: 1)
    end

    it 'year フィルタを通しても両系統で同じ打率になる' do
      mypage = BattingAverage.stats_for_user(user.id, year: '2026')
      headline = Stats::HeadlineStatsAggregator.new(user_id: user.id, year: '2026').call

      expect(mypage[:batting_average]).to eq(headline[:batting_average])
      expect(mypage[:ops]).to eq(headline[:ops])
    end
  end
end
