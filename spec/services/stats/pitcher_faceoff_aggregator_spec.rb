# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitcherFaceoffAggregator, type: :service do
  let(:single_result_id) { Stats::BattingAverageRecalculator::HIT_RESULT_IDS.first } # 7 (単打)
  let(:double_result_id) { 8 } # 二塁打
  let(:strikeout_result_id) { 13 } # 三振

  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pitcher(name)
    Pitcher.create!(name:, created_by_user: user)
  end

  def create_pa(pitcher_id:, plate_result_id:, batter_box_number: nil)
    attrs = { game_result:, user:, pitcher_id:, plate_result_id:, is_new_format: true }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns empty rows and zero total' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:rows]).to eq([])
          expect(result[:total_target_pa]).to eq(0)
          expect(result[:min_plate_appearances]).to eq(3)
        end
      end
    end

    context 'with mixed pitchers above and below threshold' do
      let!(:ace) { create_pitcher('エース投手') }
      let!(:rookie) { create_pitcher('新人投手') }
      let!(:onetime) { create_pitcher('1 度だけ投手') }

      before do
        # エース投手: 3 打席（単打 / 単打 / 三振） -> at=3, h=2, bavg=.667, top=単打 (=ヒット)
        3.times do |i|
          plate_result_id = i < 2 ? single_result_id : strikeout_result_id
          create_pa(pitcher_id: ace.id, plate_result_id:, batter_box_number: i + 1)
        end
        # 新人投手: 5 打席（二塁打 / 三振 × 4） -> at=5, h=1, bavg=.200, top=三振
        create_pa(pitcher_id: rookie.id, plate_result_id: double_result_id, batter_box_number: 10)
        4.times do |i|
          create_pa(pitcher_id: rookie.id, plate_result_id: strikeout_result_id,
                    batter_box_number: 11 + i)
        end
        # 1 度だけ投手: 1 打席（しきい値未満で除外）
        create_pa(pitcher_id: onetime.id, plate_result_id: single_result_id, batter_box_number: 20)
        # pitcher_id NULL の旧 PA は対象外
        create(:plate_appearance, game_result:, user:, batter_box_number: 99,
                                  pitcher_id: nil, plate_result_id: single_result_id,
                                  is_new_format: false)
      end

      it 'includes only pitchers with >= MIN_PLATE_APPEARANCES, ordered by appearances desc' do
        result = described_class.new(user_id: user.id).call

        names = result[:rows].pluck(:pitcher_name)
        aggregate_failures do
          # 新人 (5 PA) → エース (3 PA)。1 度だけ投手は除外
          expect(names).to eq(%w[新人投手 エース投手])
          expect(result[:total_target_pa]).to eq(9)
        end
      end

      it 'computes per-pitcher batting_average and top_result correctly' do
        result = described_class.new(user_id: user.id).call
        rookie_row = result[:rows].find { |r| r[:pitcher_name] == '新人投手' }
        ace_row = result[:rows].find { |r| r[:pitcher_name] == 'エース投手' }

        aggregate_failures do
          expect(rookie_row).to include(
            plate_appearances: 5, at_bats: 5, hits: 1,
            batting_average: 0.2, top_result: '三振'
          )
          expect(ace_row).to include(
            plate_appearances: 3, at_bats: 3, hits: 2,
            batting_average: (2.0 / 3).round(3), top_result: 'ヒット'
          )
        end
      end
    end

    context 'when tied appearances, sorts by pitcher_name asc' do
      let!(:pitcher_b) { create_pitcher('Bさん') }
      let!(:pitcher_a) { create_pitcher('Aさん') }

      before do
        3.times do |i|
          create_pa(pitcher_id: pitcher_b.id, plate_result_id: single_result_id,
                    batter_box_number: i + 1)
        end
        3.times do |i|
          create_pa(pitcher_id: pitcher_a.id, plate_result_id: single_result_id,
                    batter_box_number: 10 + i)
        end
      end

      it 'orders ties by pitcher_name ascending' do
        result = described_class.new(user_id: user.id).call

        expect(result[:rows].pluck(:pitcher_name)).to eq(%w[Aさん Bさん])
      end
    end

    context 'with year filter' do
      let!(:pitcher) { create_pitcher('対象投手') }

      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        3.times do |i|
          create(:plate_appearance, game_result: old_game, user:, batter_box_number: i + 1,
                                    pitcher_id: pitcher.id, plate_result_id: single_result_id,
                                    is_new_format: true)
        end

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        3.times do |i|
          create(:plate_appearance, game_result: new_game, user:, batter_box_number: i + 1,
                                    pitcher_id: pitcher.id, plate_result_id: double_result_id,
                                    is_new_format: true)
        end
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        row = result[:rows].first

        aggregate_failures do
          expect(result[:rows].length).to eq(1)
          expect(row[:plate_appearances]).to eq(3)
          expect(row[:hits]).to eq(3)
          expect(row[:top_result]).to eq('二塁打')
        end
      end
    end
  end
end
