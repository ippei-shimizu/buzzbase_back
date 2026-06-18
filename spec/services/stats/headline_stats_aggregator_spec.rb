# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::HeadlineStatsAggregator, type: :service do
  let(:user) { create(:user) }

  def build_game(date: '2026-04-01', match_type: 'regular', batting_attrs: {})
    game_result = create(:game_result, user:)
    game_result.match_result.update!(date_and_time: Time.zone.parse(date), match_type:)
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
    context 'when no games' do
      it 'returns zero for all stats without raising ZeroDivisionError' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:batting_average]).to eq(0.0)
          expect(result[:on_base_percentage]).to eq(0.0)
          expect(result[:slugging_percentage]).to eq(0.0)
          expect(result[:ops]).to eq(0.0)
          expect(result[:at_bats]).to eq(0)
          expect(result[:hit]).to eq(0)
          expect(result[:home_run]).to eq(0)
          expect(result[:runs_batted_in]).to eq(0)
        end
      end
    end

    context 'when summing multiple games' do
      before do
        # 1試合目: 4打数 2安打 (単打1 + 本塁打1) 2打点 1四球
        # `hit` カラムは単打のみを保持する semantics なので hit=1 (HR は home_run に別計上)
        build_game(
          batting_attrs: {
            at_bats: 4, hit: 1, two_base_hit: 0, three_base_hit: 0, home_run: 1,
            total_bases: 5, runs_batted_in: 2, base_on_balls: 1
          }
        )
        # 2試合目: 3打数 1安打 (二塁打1) 1打点 0四球 1犠飛
        # 単打 0、二塁打 1 → hit=0, two_base_hit=1
        build_game(
          batting_attrs: {
            at_bats: 3, hit: 0, two_base_hit: 1, three_base_hit: 0, home_run: 0,
            total_bases: 2, runs_batted_in: 1, base_on_balls: 0, sacrifice_fly: 1
          }
        )
      end

      it 'returns aggregated counts (sum across games)' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:at_bats]).to eq(7)
          expect(result[:hit]).to eq(3)
          expect(result[:home_run]).to eq(1)
          expect(result[:runs_batted_in]).to eq(3)
        end
      end

      it 'computes batting_average, OBP, SLG, OPS in NPB formula' do
        result = described_class.new(user_id: user.id).call

        # 打率 = 3/7 = 0.4285...
        expect(result[:batting_average]).to eq((3.0 / 7).round(3))
        # OBP = (3 + 1 + 0) / (7 + 1 + 0 + 1) = 4/9
        expect(result[:on_base_percentage]).to eq((4.0 / 9).round(3))
        # SLG = (5+2) / 7 = 1.0
        expect(result[:slugging_percentage]).to eq((7.0 / 7).round(3))
        # OPS = OBP + SLG
        expect(result[:ops]).to eq((result[:on_base_percentage] + result[:slugging_percentage]).round(3))
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
          expect(result[:at_bats]).to eq(4)
          expect(result[:hit]).to eq(2)
        end
      end
    end

    context 'with year filter' do
      before do
        build_game(date: '2025-09-30', batting_attrs: { at_bats: 4, hit: 1, total_bases: 1 })
        build_game(date: '2026-04-01', batting_attrs: { at_bats: 5, hit: 2, total_bases: 2 })
      end

      it 'only counts batting_averages within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        expect(result[:at_bats]).to eq(5)
        expect(result[:hit]).to eq(2)
      end
    end

    context 'with JST early-morning records around the year boundary' do
      before do
        build_game(date: '2026-01-01 05:00', batting_attrs: { at_bats: 4, hit: 1, total_bases: 1 })
        build_game(date: '2025-01-01 05:00', batting_attrs: { at_bats: 3, hit: 1, total_bases: 1 })
      end

      it 'JST 2026 元日 5:00 の試合が year=2026 に含まれる' do
        result = described_class.new(user_id: user.id, year: 2026).call

        expect(result[:at_bats]).to eq(4)
        expect(result[:hit]).to eq(1)
      end

      it 'JST 2025 元日 5:00 の試合が year=2025 に含まれる（前年に流れない）' do
        result = described_class.new(user_id: user.id, year: 2025).call

        expect(result[:at_bats]).to eq(3)
        expect(result[:hit]).to eq(1)
      end
    end
  end
end
