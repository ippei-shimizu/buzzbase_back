# frozen_string_literal: true

require 'rails_helper'

# `BattingAverage.stats_for_user` / `filtered_stats_for_user` 系の打率 / OBP / SLG /
# OPS が NPB 公式式と一致することを保証する retention test。
#
# 旧実装は `SUM(hit + 2B + 3B + HR) AS total_hits` と `total_bases = hit + 2*2B +
# 3*3B + 4*HR` の式で書かれており、`batting_averages.hit` が「全安打 (単打 + 2B
# + 3B + HR)」を保持しているにもかかわらず単打のみと解釈していたため、2B/3B/HR
# を二重計上して全画面（マイページ / ダッシュボード / グループランキング）で
# 打率 / OBP / OPS / ISOD が上振れていた。
RSpec.describe 'BattingAverage stats formulas', type: :model do
  let(:user) { create(:user) }

  def create_game_with_batting(date:, hit:, at_bats:, two_base_hit: 0, three_base_hit: 0, # rubocop:disable Metrics/ParameterLists
                               home_run: 0, base_on_balls: 0, hit_by_pitch: 0,
                               sacrifice_fly: 0)
    game = create(:game_result, user:)
    game.match_result.update!(date_and_time: Time.zone.parse(date), match_type: 'regular')
    # `hit` は全安打を含む semantics。単打 = hit - 2B - 3B - HR。
    singles = hit - two_base_hit - three_base_hit - home_run
    total_bases = singles + (two_base_hit * 2) + (three_base_hit * 3) + (home_run * 4)
    create(:batting_average, game_result: game, user:,
                             hit:, at_bats:, total_bases:,
                             two_base_hit:, three_base_hit:, home_run:,
                             base_on_balls:, hit_by_pitch:, sacrifice_fly:,
                             times_at_bat: at_bats + base_on_balls + hit_by_pitch + sacrifice_fly,
                             strike_out: 0, sacrifice_hit: 0)
  end

  context 'with mixed singles, doubles, triples, home runs across games' do
    before do
      # 試合 1: 4 打数 2 安打 (うち 2B 1 本) BB 1 → 単打 1 + 2B 1
      create_game_with_batting(date: '2026-04-01', hit: 2, at_bats: 4, two_base_hit: 1, base_on_balls: 1)
      # 試合 2: 3 打数 2 安打 (うち HR 1 本) → 単打 1 + HR 1
      create_game_with_batting(date: '2026-04-15', hit: 2, at_bats: 3, home_run: 1)
      # 試合 3: 5 打数 1 安打 (単打) → 単打 1
      create_game_with_batting(date: '2026-04-30', hit: 1, at_bats: 5)
    end

    # 通算: PA=13 AB=12 H=5 2B=1 3B=0 HR=1 単打=3
    # TB = 単打 1×3 + 2B 2×1 + 3B 3×0 + HR 4×1 = 3 + 2 + 0 + 4 = 9
    # BB=1 HBP=0 SF=0
    # 打率 = 5/12 = .417
    # OBP = (5+1+0)/(12+1+0+0) = 6/13 = .462
    # SLG = 9/12 = .750
    # OPS = .462 + .750 = 1.212

    it '通算打率 = SUM(hit) / SUM(at_bats) で二重計上しない' do
      result = BattingAverage.stats_for_user(user.id)

      aggregate_failures do
        expect(result[:total_hits]).to eq(5)
        expect(result[:batting_average]).to eq((5.0 / 12).round(3))
      end
    end

    it 'SLG は TB = hit + 2B + 2*3B + 3*HR で計算される' do
      result = BattingAverage.stats_for_user(user.id)

      expect(result[:slugging_percentage]).to eq((9.0 / 12).round(3))
    end

    it 'OBP = (H + BB + HBP) / (AB + BB + HBP + SF) で全安打を二重計上しない' do
      result = BattingAverage.stats_for_user(user.id)

      expect(result[:on_base_percentage]).to eq((6.0 / 13).round(3))
    end

    it 'OPS = OBP + SLG で二重計上しない' do
      result = BattingAverage.stats_for_user(user.id)
      expected_obp = (6.0 / 13).round(3)
      expected_slg = (9.0 / 12).round(3)

      expect(result[:ops]).to eq((expected_obp + expected_slg).round(3))
    end

    it 'ISOD = OBP - AVG で全安打を二重計上しない' do
      result = BattingAverage.stats_for_user(user.id)
      expected_avg = (5.0 / 12).round(3)
      expected_obp = (6.0 / 13).round(3)

      expect(result[:isod]).to eq((expected_obp - expected_avg).round(3))
    end
  end

  context 'with year filter (filtered_stats_for_user 経由)' do
    before do
      # 2025 年データ
      create_game_with_batting(date: '2025-09-30', hit: 2, at_bats: 4, two_base_hit: 1)
      # 2026 年データ
      create_game_with_batting(date: '2026-04-01', hit: 3, at_bats: 6, home_run: 1)
    end

    it 'filtered_stats_for_user でも二重計上が起きない' do
      result = BattingAverage.filtered_stats_for_user(user.id, year: '2026')

      # 2026 年のみ: hit=3 AB=6 → 打率 .500
      expect(result[:batting_average]).to eq(0.5)
    end
  end
end
