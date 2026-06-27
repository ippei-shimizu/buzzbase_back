# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::AdditionalStatsAggregator, type: :service do
  let(:user) { create(:user) }

  def build_game(date: '2026-04-01 12:00:00', batting_attrs: {})
    game_result = create(:game_result, user:)
    game_result.match_result.update!(date_and_time: Time.zone.parse(date))
    default_attrs = {
      plate_appearances: 4, times_at_bat: 4, at_bats: 4,
      hit: 1, two_base_hit: 0, three_base_hit: 0, home_run: 0, total_bases: 1,
      runs_batted_in: 0, run: 0, strike_out: 0, base_on_balls: 0,
      hit_by_pitch: 0, sacrifice_hit: 0, sacrifice_fly: 0,
      stealing_base: 0, caught_stealing: 0
    }
    create(:batting_average, game_result:, user:, **default_attrs.merge(batting_attrs))
    game_result
  end

  describe '#call' do
    context 'when no games' do
      it 'returns zero for all 16 indicators without raising' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:games]).to eq(0)
          expect(result[:plate_appearances]).to eq(0)
          expect(result[:two_base_hit]).to eq(0)
          expect(result[:three_base_hit]).to eq(0)
          expect(result[:total_bases]).to eq(0)
          expect(result[:run]).to eq(0)
          expect(result[:strike_out]).to eq(0)
          expect(result[:base_on_balls]).to eq(0)
          expect(result[:hit_by_pitch]).to eq(0)
          expect(result[:sacrifice_hit]).to eq(0)
          expect(result[:sacrifice_fly]).to eq(0)
          expect(result[:stealing_base]).to eq(0)
          expect(result[:caught_stealing]).to eq(0)
          expect(result[:iso]).to eq(0.0)
          expect(result[:isod]).to eq(0.0)
          expect(result[:bb_per_k]).to eq(0.0)
        end
      end
    end

    context 'when summing multiple games' do
      before do
        # 1試合目: 4打数 2安打 (単打1 + 本塁打1) 2打点 1四球 1得点 1三振
        # `hit` カラムは単打のみを保持する semantics なので hit=1 (HR は home_run に別計上)
        build_game(date: '2026-04-01 12:00:00', batting_attrs: {
                     plate_appearances: 5, at_bats: 4, hit: 1,
                     home_run: 1, total_bases: 5,
                     runs_batted_in: 2, run: 1, strike_out: 1,
                     base_on_balls: 1
                   })
        # 2試合目: 3打数 1安打 (二塁打1) 1打点 1犠飛 2三振 1四球 1盗塁
        # 単打 0、二塁打 1 → hit=0, two_base_hit=1
        build_game(date: '2026-04-08 12:00:00', batting_attrs: {
                     plate_appearances: 5, at_bats: 3, hit: 0, two_base_hit: 1,
                     total_bases: 2, runs_batted_in: 1, strike_out: 2,
                     base_on_balls: 1, sacrifice_fly: 1, stealing_base: 1
                   })
      end

      it 'returns aggregated counts and computed rates' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:games]).to eq(2)
          expect(result[:plate_appearances]).to eq(10)
          expect(result[:two_base_hit]).to eq(1)
          expect(result[:total_bases]).to eq(7)
          expect(result[:run]).to eq(1)
          expect(result[:strike_out]).to eq(3)
          expect(result[:base_on_balls]).to eq(2)
          expect(result[:sacrifice_fly]).to eq(1)
          expect(result[:stealing_base]).to eq(1)
          # 打率 = 3/7 = .429, 出塁率 = (3+2+0)/(7+2+0+1) = 5/10 = .500, 長打率 = 7/7 = 1.000
          # ISO = 長打率 - 打率 = 1.000 - .429 = .571
          # ISOD = 出塁率 - 打率 = .500 - .429 = .071
          # BB/K = 2/3 = .667
          expect(result[:iso]).to eq((1.0 - (3.0 / 7)).round(3))
          expect(result[:isod]).to eq((0.5 - (3.0 / 7)).round(3))
          expect(result[:bb_per_k]).to eq((2.0 / 3).round(3))
        end
      end
    end

    context 'with year filter' do
      before do
        build_game(date: '2025-09-30 12:00:00',
                   batting_attrs: { at_bats: 4, hit: 1, total_bases: 1 })
        build_game(date: '2026-04-01 12:00:00',
                   batting_attrs: { at_bats: 5, hit: 2, total_bases: 2 })
      end

      it 'only counts batting_averages within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        aggregate_failures do
          expect(result[:games]).to eq(1)
          expect(result[:total_bases]).to eq(2)
        end
      end
    end

    context 'with strike_out swing_type breakdown' do
      let!(:game_result) do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.parse('2026-04-01 12:00:00'))
        gr
      end

      before do
        # 新仕様 PA: 空振り三振 ×2、見逃し三振 ×1、swing_type 未指定の三振 ×1、振り逃げ ×1、ヒット ×1
        create(:plate_appearance, game_result:, user:, batter_box_number: 1,
                                  plate_result_id: 13, swing_type: :swinging, is_new_format: true)
        create(:plate_appearance, game_result:, user:, batter_box_number: 2,
                                  plate_result_id: 13, swing_type: :swinging, is_new_format: true)
        create(:plate_appearance, game_result:, user:, batter_box_number: 3,
                                  plate_result_id: 13, swing_type: :looking, is_new_format: true)
        create(:plate_appearance, game_result:, user:, batter_box_number: 4,
                                  plate_result_id: 13, is_new_format: true)
        create(:plate_appearance, game_result:, user:, batter_box_number: 5,
                                  plate_result_id: 14, is_new_format: true)
        create(:plate_appearance, game_result:, user:, batter_box_number: 6,
                                  plate_result_id: 7, is_new_format: true)
        # 旧 PA も投入 → 内訳には含めない
        create(:plate_appearance, game_result:, user:, batter_box_number: 7,
                                  plate_result_id: 13, is_new_format: false)
      end

      it 'returns swinging / looking breakdown from new-format PAs only' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:swinging_strike_out]).to eq(2)
          expect(result[:looking_strike_out]).to eq(1)
        end
      end
    end
  end
end
