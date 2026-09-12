# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitchCoursePitchTypeAggregator, type: :service do
  let(:single_result_id) { Stats::BattingAverageRecalculator::HIT_RESULT_IDS.first } # 7 (単打)
  let(:strikeout_result_id) { 13 } # 三振

  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(pitch_type_id:, pitch_course:, plate_result_id:)
    create(:plate_appearance, game_result:, user:, pitch_type_id:, pitch_course:,
                              plate_result_id:, is_new_format: true)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns all 10 master rows each with 25 zero zones' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:rows].length).to eq(10)
          expect(result[:rows].first[:zones].length).to eq(25)
          expect(result[:rows].first[:zones].pluck(:at_bats)).to all(eq(0))
          expect(result[:total_target_pa]).to eq(0)
          expect(result[:min_at_bats]).to eq(3)
        end
      end

      it 'orders rows by master display_order' do
        result = described_class.new(user_id: user.id).call

        expect(result[:rows].first[:label]).to eq('ストレート系')
        expect(result[:rows].last[:label]).to eq('チェンジアップ系')
      end
    end

    context 'with recorded courses per pitch type' do
      before do
        # ストレート系 (id=1) x 真ん中 (13): 単打 + 三振
        create_pa(pitch_type_id: 1, pitch_course: 13, plate_result_id: single_result_id)
        create_pa(pitch_type_id: 1, pitch_course: 13, plate_result_id: strikeout_result_id)
        # スライダー系 (id=5) x 外角低め (19): 単打
        create_pa(pitch_type_id: 5, pitch_course: 19, plate_result_id: single_result_id)
        # コースだけ記録され球種が無い PA はクロス集計の対象外
        create(:plate_appearance, game_result:, user:, pitch_type_id: nil, pitch_course: 13,
                                  plate_result_id: single_result_id, is_new_format: true)
      end

      it 'aggregates cells per (pitch_type, course)' do
        result = described_class.new(user_id: user.id).call
        straight = result[:rows].find { |r| r[:label] == 'ストレート系' }
        slider = result[:rows].find { |r| r[:label] == 'スライダー系' }
        straight_center = straight[:zones].find { |z| z[:course] == 13 }
        slider_low_outside = slider[:zones].find { |z| z[:course] == 19 }

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(3)
          expect(straight[:plate_appearances]).to eq(2)
          expect(straight_center).to include(at_bats: 2, hits: 1, batting_average: 0.5)
          expect(slider_low_outside).to include(at_bats: 1, hits: 1, batting_average: 1.0)
          # 他セルは 0 のまま
          expect(straight[:zones].sum { |z| z[:plate_appearances] }).to eq(2)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, pitch_type_id: 1, pitch_course: 13,
                                  plate_result_id: single_result_id, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, pitch_type_id: 1, pitch_course: 13,
                                  plate_result_id: strikeout_result_id, is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        expect(result[:total_target_pa]).to eq(1)
      end
    end
  end
end
