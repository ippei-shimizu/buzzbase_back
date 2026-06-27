# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitchTypeAggregator, type: :service do
  # plate_result_id の SSoT は Stats::BattingAverageRecalculator::HIT_RESULT_IDS。
  let(:single_result_id) { Stats::BattingAverageRecalculator::HIT_RESULT_IDS.first } # 7 (単打)
  let(:double_result_id) { 8 } # 二塁打
  let(:home_run_result_id) { 10 } # 本塁打
  let(:strikeout_result_id) { 13 } # 三振

  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(pitch_type_id:, plate_result_id:, batter_box_number: nil)
    attrs = { game_result:, user:, pitch_type_id:, plate_result_id:, is_new_format: true }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns all 10 master rows with zero stats and total_target_pa 0' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(0)
          expect(result[:rows].length).to eq(10)
          expect(result[:rows].pluck(:at_bats)).to all(eq(0))
          expect(result[:rows].pluck(:batting_average)).to all(eq(0.0))
        end
      end

      it 'orders rows by master display_order' do
        result = described_class.new(user_id: user.id).call

        expect(result[:rows].first[:label]).to eq('ストレート系')
        expect(result[:rows].last[:label]).to eq('チェンジアップ系')
      end
    end

    context 'with mixed pitch_types and results' do
      before do
        # ストレート系 (id=1): 単打 + 三振 = 2打数 1安打
        create_pa(pitch_type_id: 1, plate_result_id: single_result_id)
        create_pa(pitch_type_id: 1, plate_result_id: strikeout_result_id)
        # スライダー系 (id=5): 二塁打 + 本塁打 = 2打数 2安打 (total_bases=6)
        create_pa(pitch_type_id: 5, plate_result_id: double_result_id)
        create_pa(pitch_type_id: 5, plate_result_id: home_run_result_id)
        # pitch_type_id NULL の旧 PA は対象外
        create(:plate_appearance, game_result:, user:, batter_box_number: 99,
                                  pitch_type_id: nil, plate_result_id: single_result_id,
                                  is_new_format: false)
      end

      it 'aggregates at_bats / hits / total_bases / averages per pitch_type' do
        result = described_class.new(user_id: user.id).call
        straight = result[:rows].find { |r| r[:label] == 'ストレート系' }
        slider = result[:rows].find { |r| r[:label] == 'スライダー系' }

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(4)

          expect(straight[:at_bats]).to eq(2)
          expect(straight[:hits]).to eq(1)
          expect(straight[:total_bases]).to eq(1)
          expect(straight[:batting_average]).to eq(0.5)
          expect(straight[:slugging_percentage]).to eq(0.5)

          expect(slider[:at_bats]).to eq(2)
          expect(slider[:hits]).to eq(2)
          expect(slider[:total_bases]).to eq(6)
          expect(slider[:batting_average]).to eq(1.0)
          expect(slider[:slugging_percentage]).to eq(3.0)
        end
      end

      it 'exposes extended stats (PA / BB / HBP / SF / OBP / OPS / result_counts) per row' do
        result = described_class.new(user_id: user.id).call
        straight = result[:rows].find { |r| r[:label] == 'ストレート系' }
        slider = result[:rows].find { |r| r[:label] == 'スライダー系' }

        aggregate_failures do
          # ストレート: 単打 1 + 三振 1 → PA=2 AB=2 H=1 TB=1 BB=0 HBP=0 SF=0
          expect(straight).to include(
            plate_appearances: 2, base_on_balls: 0, hit_by_pitch: 0, sacrifice_fly: 0
          )
          expect(straight[:on_base_percentage]).to eq(0.5)
          expect(straight[:ops]).to eq(1.0)
          expect(straight[:result_counts]).to eq([
                                                   { plate_result_id: single_result_id, plate_result_name: 'ヒット', count: 1 },
                                                   { plate_result_id: strikeout_result_id, plate_result_name: '三振', count: 1 }
                                                 ])

          # スライダー: 二塁打 + 本塁打 → PA=2 AB=2 H=2 TB=6 / OBP=1.000 / OPS=4.000
          expect(slider).to include(plate_appearances: 2)
          expect(slider[:on_base_percentage]).to eq(1.0)
          expect(slider[:ops]).to eq(4.0)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, batter_box_number: 1,
                                  pitch_type_id: 1, plate_result_id: single_result_id,
                                  is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, batter_box_number: 1,
                                  pitch_type_id: 1, plate_result_id: double_result_id,
                                  is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        straight = result[:rows].find { |r| r[:label] == 'ストレート系' }

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(1)
          expect(straight[:at_bats]).to eq(1)
          expect(straight[:hits]).to eq(1)
          expect(straight[:total_bases]).to eq(2)
        end
      end
    end
  end
end
