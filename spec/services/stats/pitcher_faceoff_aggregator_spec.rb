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

      it 'exposes total_bases / BB / HBP / SF / OBP / SLG / OPS per pitcher' do
        result = described_class.new(user_id: user.id).call
        rookie_row = result[:rows].find { |r| r[:pitcher_name] == '新人投手' }
        ace_row = result[:rows].find { |r| r[:pitcher_name] == 'エース投手' }

        aggregate_failures do
          # エース: 単打 2 + 三振 1 → AB=3 H=2 TB=2 BB=0 HBP=0 SF=0
          expect(ace_row).to include(
            total_bases: 2,
            base_on_balls: 0, hit_by_pitch: 0, sacrifice_fly: 0
          )
          # OBP = (2+0+0)/(3+0+0+0) = .667, SLG = 2/3 = .667, OPS = 1.333
          expect(ace_row[:on_base_percentage]).to eq((2.0 / 3).round(3))
          expect(ace_row[:slugging_percentage]).to eq((2.0 / 3).round(3))
          expect(ace_row[:ops]).to eq(
            ((2.0 / 3).round(3) + (2.0 / 3).round(3)).round(3)
          )

          # 新人: 二塁打 1 + 三振 4 → AB=5 H=1 TB=2
          expect(rookie_row).to include(total_bases: 2, base_on_balls: 0)
        end
      end

      it 'exposes result_counts sorted by plate_result_id with name + count' do
        result = described_class.new(user_id: user.id).call
        ace_row = result[:rows].find { |r| r[:pitcher_name] == 'エース投手' }
        rookie_row = result[:rows].find { |r| r[:pitcher_name] == '新人投手' }

        aggregate_failures do
          # エース: 単打 2 + 三振 1
          expect(ace_row[:result_counts]).to eq([
                                                  { plate_result_id: single_result_id, plate_result_name: 'ヒット', count: 2 },
                                                  { plate_result_id: strikeout_result_id, plate_result_name: '三振', count: 1 }
                                                ])
          # 新人: 二塁打 1 + 三振 4
          expect(rookie_row[:result_counts]).to eq([
                                                     { plate_result_id: double_result_id, plate_result_name: '二塁打', count: 1 },
                                                     { plate_result_id: strikeout_result_id, plate_result_name: '三振', count: 4 }
                                                   ])
        end
      end
    end

    context 'with pitcher attributes (team / throw_hand / style / velocity_zone)' do
      let!(:team) { create(:team, name: '対戦チーム') }
      let(:pitcher_style) { PitcherStyle.find_by!(name: '本格派') }
      let(:velocity_zone) { VelocityZone.find_by!(name: '140-150km/h') }
      let!(:lefty) do
        Pitcher.create!(name: '左腕投手', created_by_user: user, team:,
                        throw_hand: :left, pitcher_style:, velocity_zone:)
      end
      let!(:bare) { create_pitcher('属性なし投手') }

      before do
        3.times { |i| create_pa(pitcher_id: lefty.id, plate_result_id: single_result_id, batter_box_number: i + 1) }
        3.times { |i| create_pa(pitcher_id: bare.id, plate_result_id: single_result_id, batter_box_number: 10 + i) }
      end

      it 'exposes team_name / throw_hand / pitcher_style / velocity_zone, nil when unset' do
        result = described_class.new(user_id: user.id).call
        lefty_row = result[:rows].find { |r| r[:pitcher_name] == '左腕投手' }
        bare_row = result[:rows].find { |r| r[:pitcher_name] == '属性なし投手' }

        aggregate_failures do
          expect(lefty_row).to include(
            team_name: '対戦チーム', throw_hand: 'left',
            pitcher_style: '本格派', velocity_zone: '140-150km/h'
          )
          expect(bare_row).to include(
            team_name: nil, throw_hand: nil, pitcher_style: nil, velocity_zone: nil
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
