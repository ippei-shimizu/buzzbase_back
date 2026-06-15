# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::CountSituationAggregator, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(plate_result_id:, first_pitch_swing: nil, final_balls: nil, final_strikes: nil, batter_box_number: nil)
    attrs = {
      game_result:, user:, plate_result_id:,
      first_pitch_swing:, final_balls:, final_strikes:, is_new_format: true
    }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no new-format plate appearances' do
      it 'returns zero母数 for all situations' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(0)
          expect(result[:first_pitch][:at_bats]).to eq(0)
          expect(result[:first_pitch][:hits]).to eq(0)
          expect(result[:first_pitch][:batting_average]).to eq(0.0)
          expect(result[:favorable_count][:at_bats]).to eq(0)
          expect(result[:pinch_count][:at_bats]).to eq(0)
        end
      end
    end

    context 'with first_pitch_swing PAs' do
      before do
        # 初球を振ってヒット
        create_pa(plate_result_id: 7, first_pitch_swing: true, final_balls: 0, final_strikes: 1)
        # 初球を振って三振
        create_pa(plate_result_id: 13, first_pitch_swing: true, final_balls: 0, final_strikes: 1)
        # 初球を振らずヒット（first_pitch のカウントから除外）
        create_pa(plate_result_id: 7, first_pitch_swing: false, final_balls: 2, final_strikes: 1)
      end

      it 'aggregates only PAs where first_pitch_swing = TRUE for first_pitch' do
        result = described_class.new(user_id: user.id).call
        first_pitch = result[:first_pitch]

        aggregate_failures do
          expect(first_pitch[:at_bats]).to eq(2)
          expect(first_pitch[:hits]).to eq(1)
          expect(first_pitch[:batting_average]).to eq((1.0 / 2).round(3))
        end
      end
    end

    context 'with favorable_count PAs' do
      before do
        # 有利カウント (final_balls > final_strikes): ヒット
        create_pa(plate_result_id: 7, first_pitch_swing: false, final_balls: 2, final_strikes: 1)
        # 有利カウント: 三振
        create_pa(plate_result_id: 13, first_pitch_swing: false, final_balls: 3, final_strikes: 2)
        # 不利カウント (final_balls <= final_strikes): 除外
        create_pa(plate_result_id: 7, first_pitch_swing: false, final_balls: 1, final_strikes: 2)
      end

      it 'aggregates only PAs where final_balls > final_strikes for favorable_count' do
        result = described_class.new(user_id: user.id).call
        favorable = result[:favorable_count]

        aggregate_failures do
          expect(favorable[:at_bats]).to eq(2)
          expect(favorable[:hits]).to eq(1)
          expect(favorable[:batting_average]).to eq((1.0 / 2).round(3))
        end
      end
    end

    context 'with pinch_count PAs' do
      before do
        # 追い込みカウント (final_strikes = 2): ヒット
        create_pa(plate_result_id: 7, first_pitch_swing: false, final_balls: 1, final_strikes: 2)
        # 追い込みカウント: 三振
        create_pa(plate_result_id: 13, first_pitch_swing: false, final_balls: 0, final_strikes: 2)
        # 追い込みではない (final_strikes < 2): 除外
        create_pa(plate_result_id: 7, first_pitch_swing: false, final_balls: 0, final_strikes: 1)
      end

      it 'aggregates only PAs where final_strikes = 2 for pinch_count' do
        result = described_class.new(user_id: user.id).call
        pinch = result[:pinch_count]

        aggregate_failures do
          expect(pinch[:at_bats]).to eq(2)
          expect(pinch[:hits]).to eq(1)
          expect(pinch[:batting_average]).to eq((1.0 / 2).round(3))
        end
      end
    end

    context 'when plate_result_id is NULL' do
      before do
        # plate_result_id 未入力（カウントは記録されているが結果未入力）の PA。
        # joins(:plate_result) の INNER JOIN で除外されるため total_target_pa にも含めない。
        create(:plate_appearance, game_result:, user:, batter_box_number: 50,
                                  plate_result_id: nil,
                                  first_pitch_swing: true, final_balls: 0, final_strikes: 1,
                                  is_new_format: true)
      end

      it 'excludes PAs whose plate_result_id is NULL from total_target_pa' do
        result = described_class.new(user_id: user.id).call

        expect(result[:total_target_pa]).to eq(0)
      end
    end

    context 'when old-format PA only (NULL final_strikes)' do
      before do
        create(:plate_appearance, game_result:, user:, batter_box_number: 99,
                                  plate_result_id: 7,
                                  first_pitch_swing: nil, final_balls: nil, final_strikes: nil,
                                  is_new_format: false)
      end

      it 'excludes old-format PAs from filtered_scope' do
        result = described_class.new(user_id: user.id).call

        expect(result[:total_target_pa]).to eq(0)
      end
    end

    context 'with full count (3-2) PA' do
      before do
        # フルカウント: final_balls > final_strikes と final_strikes = 2 の両方を満たす
        create_pa(plate_result_id: 7, first_pitch_swing: false, final_balls: 3, final_strikes: 2)
      end

      it 'counts the same PA in both favorable_count and pinch_count (排他ではない仕様)' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:favorable_count][:at_bats]).to eq(1)
          expect(result[:favorable_count][:hits]).to eq(1)
          expect(result[:pinch_count][:at_bats]).to eq(1)
          expect(result[:pinch_count][:hits]).to eq(1)
          # 母数 (total_target_pa) は 1 のままで、重複計上はカテゴリ内のみ
          expect(result[:total_target_pa]).to eq(1)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, batter_box_number: 1,
                                  plate_result_id: 7, first_pitch_swing: true,
                                  final_balls: 0, final_strikes: 1, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, batter_box_number: 1,
                                  plate_result_id: 8, first_pitch_swing: true,
                                  final_balls: 0, final_strikes: 1, is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(1)
          expect(result[:first_pitch][:at_bats]).to eq(1)
          expect(result[:first_pitch][:hits]).to eq(1)
        end
      end
    end
  end
end
