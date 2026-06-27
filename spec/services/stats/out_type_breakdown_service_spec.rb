# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::OutTypeBreakdownService, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(out_type:, batter_box_number: nil)
    attrs = { game_result:, user:, out_type:, is_new_format: true }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns all enum categories with zero count and total 0' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:total]).to eq(0)
          expect(result[:breakdown].pluck(:category))
            .to contain_exactly('ゴロ', 'フライ', 'ライナー', '併殺打', 'ファールフライ')
          expect(result[:breakdown].pluck(:count)).to all(eq(0))
          expect(result[:breakdown].pluck(:percentage)).to all(eq(0.0))
        end
      end
    end

    context 'with mixed out_type values' do
      before do
        create_pa(out_type: :ground_ball)
        create_pa(out_type: :ground_ball)
        create_pa(out_type: :fly_ball)
        create_pa(out_type: :line_drive)
        # out_type NULL の PA は集計対象外
        create(:plate_appearance, game_result:, user:, batter_box_number: 99,
                                  out_type: nil, is_new_format: false)
      end

      it 'aggregates count / percentage for each enum, excluding NULL' do
        result = described_class.new(user_id: user.id).call

        ground = result[:breakdown].find { |b| b[:category] == 'ゴロ' }
        fly = result[:breakdown].find { |b| b[:category] == 'フライ' }
        liner = result[:breakdown].find { |b| b[:category] == 'ライナー' }
        foul = result[:breakdown].find { |b| b[:category] == 'ファールフライ' }
        aggregate_failures do
          expect(result[:total]).to eq(4)
          expect(ground[:count]).to eq(2)
          expect(ground[:percentage]).to eq(50.0)
          expect(fly[:count]).to eq(1)
          expect(fly[:percentage]).to eq(25.0)
          expect(liner[:count]).to eq(1)
          expect(foul[:count]).to eq(0)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, batter_box_number: 1,
                                  out_type: :ground_ball, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, batter_box_number: 1,
                                  out_type: :fly_ball, is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        fly = result[:breakdown].find { |b| b[:category] == 'フライ' }

        aggregate_failures do
          expect(result[:total]).to eq(1)
          expect(fly[:count]).to eq(1)
        end
      end
    end
  end
end
