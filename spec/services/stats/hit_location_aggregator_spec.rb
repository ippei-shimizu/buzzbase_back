# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::HitLocationAggregator, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(loc_x:, loc_y:, plate_result_id:, batter_box_number: nil)
    attrs = {
      game_result:, user:, hit_location_x: loc_x, hit_location_y: loc_y,
      plate_result_id:, is_new_format: true
    }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns empty points' do
        result = described_class.new(user_id: user.id).call

        expect(result[:points]).to eq([])
      end
    end

    context 'with categorized plate_results' do
      before do
        create_pa(loc_x: 0.30, loc_y: 0.40, plate_result_id: 7)  # 単打 → hit
        create_pa(loc_x: 0.50, loc_y: 0.20, plate_result_id: 10) # 本塁打 → hit
        create_pa(loc_x: 0.40, loc_y: 0.60, plate_result_id: 1)  # ゴロ → out
        create_pa(loc_x: 0.60, loc_y: 0.45, plate_result_id: 2)  # フライ → out
        create_pa(loc_x: 0.55, loc_y: 0.50, plate_result_id: 17) # 失策 → other
      end

      it 'categorizes each point as hit / out / other' do
        result = described_class.new(user_id: user.id).call

        categories = result[:points].pluck(:category)
        aggregate_failures do
          expect(categories).to contain_exactly('hit', 'hit', 'out', 'out', 'other')
          expect(result[:points].first).to include(:x, :y, :category, :plate_result_id)
        end
      end
    end

    context 'when hit_location_x or y is NULL' do
      before do
        create_pa(loc_x: 0.5, loc_y: 0.5, plate_result_id: 7)
        create(:plate_appearance, game_result:, user:, batter_box_number: 99,
                                  hit_location_x: nil, hit_location_y: nil,
                                  plate_result_id: 7, is_new_format: false)
      end

      it 'excludes plate appearances with NULL coordinates' do
        result = described_class.new(user_id: user.id).call

        expect(result[:points].length).to eq(1)
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, batter_box_number: 1,
                                  hit_location_x: 0.4, hit_location_y: 0.4,
                                  plate_result_id: 7, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, batter_box_number: 1,
                                  hit_location_x: 0.6, hit_location_y: 0.6,
                                  plate_result_id: 7, is_new_format: true)
      end

      it 'only returns points within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        aggregate_failures do
          expect(result[:points].length).to eq(1)
          expect(result[:points].first[:x]).to eq(0.6)
        end
      end
    end
  end
end
