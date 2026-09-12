# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::BattingTrendAggregator, type: :service do
  let(:user) { create(:user) }

  def build_game(date:, match_type: 'regular', batting_attrs: {})
    game_result = create(:game_result, user:)
    # 月境界をまたぐ TZ 起因の取りこぼしを避けるため、日付には明示的に 12:00:00 を付ける。
    # 真の TZ 対応は Sub #371（stats 系の年度フィルタを Time.zone ベースに統一）の範囲。
    parsed = Time.zone.parse(date.include?(' ') ? date : "#{date} 12:00:00")
    game_result.match_result.update!(date_and_time: parsed, match_type:)
    default_attrs = {
      plate_appearances: 4, times_at_bat: 4, at_bats: 4,
      hit: 1, two_base_hit: 0, three_base_hit: 0, home_run: 0,
      total_bases: 1, runs_batted_in: 0, base_on_balls: 0,
      hit_by_pitch: 0, sacrifice_fly: 0, sacrifice_hit: 0
    }
    create(:batting_average, game_result:, user:, **default_attrs.merge(batting_attrs))
    game_result
  end

  describe '#call' do
    context 'when no batting averages' do
      it 'returns empty points' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:granularity]).to eq('game')
          expect(result[:points]).to eq([])
        end
      end
    end

    context 'with granularity=game (default, cumulative)' do
      before do
        # 試合 1: 4 打数 2 安打 (打率 .500)
        build_game(date: '2026-04-01', batting_attrs: {
                     at_bats: 4, hit: 2, total_bases: 2, base_on_balls: 0
                   })
        # 試合 2: 3 打数 1 安打 (累計 7-3 = .429)
        build_game(date: '2026-04-15', batting_attrs: {
                     at_bats: 3, hit: 1, total_bases: 2, base_on_balls: 1
                   })
      end

      it 'returns 2 points with cumulative batting_average / OBP / SLG / OPS' do
        result = described_class.new(user_id: user.id).call
        points = result[:points]

        aggregate_failures do
          expect(points.length).to eq(2)
          expect(points[0][:batting_average]).to eq((2.0 / 4).round(3))
          expect(points[0][:cumulative_at_bats]).to eq(4)
          expect(points[0][:at_bats_in_period]).to eq(4)
          # 2 試合目: 累計 at_bats=7, hit=3, total_bases=4, base_on_balls=1
          expect(points[1][:batting_average]).to eq((3.0 / 7).round(3))
          # OBP = (3 + 1 + 0) / (7 + 1 + 0 + 0) = 4/8 = 0.5
          expect(points[1][:on_base_percentage]).to eq(0.5)
          # SLG = 4/7
          expect(points[1][:slugging_percentage]).to eq((4.0 / 7).round(3))
          # OPS = OBP + SLG
          expect(points[1][:ops])
            .to eq((points[1][:on_base_percentage] + points[1][:slugging_percentage]).round(3))
          expect(points[1][:cumulative_at_bats]).to eq(7)
          expect(points[1][:at_bats_in_period]).to eq(3)
        end
      end

      it 'returns points sorted by date ascending' do
        result = described_class.new(user_id: user.id).call
        points = result[:points]

        expect(points.pluck(:label)).to eq(['4/1', '4/15'])
      end
    end

    context 'with granularity=month' do
      before do
        # 4 月: 4-2 (.500) + 3-1 (.333) = 7-3 (.429)
        build_game(date: '2026-04-01', batting_attrs: { at_bats: 4, hit: 2, total_bases: 2 })
        build_game(date: '2026-04-15', batting_attrs: { at_bats: 3, hit: 1, total_bases: 2 })
        # 5 月: 5-3 (.600)
        build_game(date: '2026-05-02', batting_attrs: { at_bats: 5, hit: 3, total_bases: 5 })
      end

      it 'aggregates per month and returns standalone (not cumulative) averages' do
        result = described_class.new(user_id: user.id, granularity: 'month').call
        points = result[:points]

        aggregate_failures do
          expect(result[:granularity]).to eq('month')
          expect(points.length).to eq(2)
          expect(points[0][:label]).to eq('4月')
          expect(points[0][:batting_average]).to eq((3.0 / 7).round(3))
          expect(points[0][:at_bats_in_period]).to eq(7)
          expect(points[1][:label]).to eq('5月')
          # 5 月単独 (cumulative ではなく)
          expect(points[1][:batting_average]).to eq((3.0 / 5).round(3))
          expect(points[1][:slugging_percentage]).to eq((5.0 / 5).round(3))
        end
      end
    end

    context 'with year filter' do
      before do
        build_game(date: '2025-09-30', batting_attrs: { at_bats: 4, hit: 1, total_bases: 1 })
        build_game(date: '2026-04-01', batting_attrs: { at_bats: 5, hit: 2, total_bases: 2 })
      end

      it 'only includes games within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        aggregate_failures do
          expect(result[:points].length).to eq(1)
          expect(result[:points].first[:label]).to eq('4/1')
          expect(result[:points].first[:cumulative_at_bats]).to eq(5)
        end
      end
    end

    context 'with match_type filter' do
      before do
        build_game(date: '2026-04-01', match_type: 'regular',
                   batting_attrs: { at_bats: 4, hit: 2, total_bases: 2 })
        build_game(date: '2026-04-02', match_type: 'open',
                   batting_attrs: { at_bats: 3, hit: 0, total_bases: 0 })
      end

      it 'only counts batting_averages whose match_results.match_type matches' do
        result = described_class.new(user_id: user.id, match_type: 'regular').call

        aggregate_failures do
          expect(result[:points].length).to eq(1)
          expect(result[:points].first[:cumulative_at_bats]).to eq(4)
        end
      end
    end

    context 'with JST early-morning records around the month boundary (granularity=month)' do
      before do
        # JST 2026-01-01 05:00 → UTC 2025-12-31 20:00。UTC ベース EXTRACT だと
        # 12月扱いになるが、JST 評価では 1月にバケットされる必要がある。
        build_game(date: '2026-01-01 05:00',
                   batting_attrs: { at_bats: 4, hit: 1, total_bases: 1 })
        build_game(date: '2026-02-15 12:00',
                   batting_attrs: { at_bats: 5, hit: 2, total_bases: 2 })
      end

      it 'JST 1月1日 早朝の試合は 1月にバケットされる（12月に流れない）' do
        result = described_class.new(user_id: user.id, granularity: 'month').call
        points = result[:points]

        aggregate_failures do
          expect(points.length).to eq(2)
          expect(points[0][:label]).to eq('1月')
          expect(points[0][:at_bats_in_period]).to eq(4)
          expect(points[1][:label]).to eq('2月')
        end
      end
    end
  end
end
