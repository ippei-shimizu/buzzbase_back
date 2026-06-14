# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::HitDirectionAggregator, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(hit_direction_id:, plate_result_id:, batter_box_number: nil)
    attrs = { game_result:, user:, hit_direction_id:, plate_result_id:, is_new_format: true }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns directions with all zero stats' do
        result = described_class.new(user_id: user.id).call

        left = result[:directions].find { |d| d[:id] == 8 }
        aggregate_failures do
          expect(left[:count]).to eq(0)
          expect(left[:at_bats]).to eq(0)
          expect(left[:hits]).to eq(0)
          expect(left[:total_bases]).to eq(0)
        end
        expect(result[:home_runs]).to be_empty
      end
    end

    context 'with mixed results in 左方向 (id=8)' do
      before do
        # 単打 / 三振 / 四球 / 二塁打 / 本塁打 が左方向に混在
        create_pa(hit_direction_id: 8, plate_result_id: 7)  # 単打
        create_pa(hit_direction_id: 8, plate_result_id: 13) # 三振
        create_pa(hit_direction_id: 8, plate_result_id: 15) # 四球（打数外）
        create_pa(hit_direction_id: 8, plate_result_id: 8)  # 二塁打
        create_pa(hit_direction_id: 8, plate_result_id: 10) # 本塁打
      end

      it 'aggregates at_bats / hits / two_base_hit / total_bases / home_run for that direction' do
        result = described_class.new(user_id: user.id).call
        left = result[:directions].find { |d| d[:id] == 8 }

        aggregate_failures do
          # 単打 + 三振 + 二塁打 + 本塁打 = 4打数 (四球は除外)
          expect(left[:at_bats]).to eq(4)
          # 単打 + 二塁打 + 本塁打
          expect(left[:hits]).to eq(3)
          expect(left[:two_base_hit]).to eq(1)
          expect(left[:three_base_hit]).to eq(0)
          expect(left[:home_run]).to eq(1)
          # 単打1 + 二塁打2 + 本塁打4
          expect(left[:total_bases]).to eq(7)
        end
      end

      it 'returns home_runs with that direction' do
        result = described_class.new(user_id: user.id).call

        expect(result[:home_runs].pluck(:id)).to include(8)
      end
    end

    context 'with three_base_hit' do
      before do
        create_pa(hit_direction_id: 9, plate_result_id: 9) # 左中への三塁打
      end

      it 'counts three_base_hit and total_bases correctly' do
        result = described_class.new(user_id: user.id).call
        left_center = result[:directions].find { |d| d[:id] == 9 }

        aggregate_failures do
          expect(left_center[:at_bats]).to eq(1)
          expect(left_center[:hits]).to eq(1)
          expect(left_center[:three_base_hit]).to eq(1)
          expect(left_center[:total_bases]).to eq(3)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, batter_box_number: 1,
                                  hit_direction_id: 8, plate_result_id: 7, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, batter_box_number: 1,
                                  hit_direction_id: 8, plate_result_id: 8, is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        left = result[:directions].find { |d| d[:id] == 8 }

        aggregate_failures do
          expect(left[:at_bats]).to eq(1)
          expect(left[:two_base_hit]).to eq(1)
          expect(left[:total_bases]).to eq(2)
        end
      end
    end

    context 'with legacy batting_position_id (旧仕様)' do
      before do
        # batting_position_id=7 (旧仕様の左) → hit_direction_id=8 にマップされる
        create(:plate_appearance, game_result:, user:, batter_box_number: 1,
                                  batting_position_id: 7, plate_result_id: 7, is_new_format: false)
      end

      it 'maps legacy batting_position_id to direction id' do
        result = described_class.new(user_id: user.id).call
        left = result[:directions].find { |d| d[:id] == 8 }

        aggregate_failures do
          expect(left[:count]).to eq(1)
          expect(left[:at_bats]).to eq(1)
          expect(left[:hits]).to eq(1)
        end
      end
    end
  end
end
