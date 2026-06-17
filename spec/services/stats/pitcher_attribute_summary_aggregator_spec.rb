# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitcherAttributeSummaryAggregator, type: :service do
  let(:single_result_id) { Stats::BattingAverageRecalculator::HIT_RESULT_IDS.first } # 7 (単打)
  let(:double_result_id) { 8 }
  let(:strikeout_result_id) { 13 }

  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pitcher(name:, throw_hand: :right, arm_angle_id: nil, velocity_zone_id: nil, pitcher_style_id: nil)
    Pitcher.create!(name:, throw_hand:, arm_angle_id:, velocity_zone_id:, pitcher_style_id:,
                    created_by_user: user)
  end

  def create_pa(pitcher_id:, plate_result_id:, batter_box_number: nil, game: game_result)
    attrs = { game_result: game, user:, pitcher_id:, plate_result_id:, is_new_format: true }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns 4 empty arrays' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:by_throw_hand]).to eq([])
          expect(result[:by_arm_angle]).to eq([])
          expect(result[:by_velocity_zone]).to eq([])
          expect(result[:by_pitcher_style]).to eq([])
        end
      end
    end

    context 'with mixed pitchers across attributes' do
      let!(:right_over) do
        create_pitcher(name: '右オーバー投手', throw_hand: :right, arm_angle_id: 1,
                       velocity_zone_id: 3, pitcher_style_id: 1)
      end
      let!(:left_side) do
        create_pitcher(name: '左サイド投手', throw_hand: :left, arm_angle_id: 3,
                       velocity_zone_id: 2, pitcher_style_id: 2)
      end
      let!(:unset_pitcher) { create_pitcher(name: '属性なし投手', throw_hand: :right) }

      before do
        # 右オーバー: 4 PA = 単打 2 + 三振 2 → at=4, h=2
        2.times { |i| create_pa(pitcher_id: right_over.id, plate_result_id: single_result_id, batter_box_number: i + 1) }
        2.times { |i| create_pa(pitcher_id: right_over.id, plate_result_id: strikeout_result_id, batter_box_number: i + 3) }
        # 左サイド: 3 PA = 二塁打 1 + 三振 2 → at=3, h=1
        create_pa(pitcher_id: left_side.id, plate_result_id: double_result_id, batter_box_number: 10)
        2.times { |i| create_pa(pitcher_id: left_side.id, plate_result_id: strikeout_result_id, batter_box_number: 11 + i) }
        # 属性なし: 2 PA = 単打 1 + 三振 1 → at=2, h=1
        create_pa(pitcher_id: unset_pitcher.id, plate_result_id: single_result_id, batter_box_number: 20)
        create_pa(pitcher_id: unset_pitcher.id, plate_result_id: strikeout_result_id, batter_box_number: 21)
      end

      it 'buckets by throw_hand with right(0) before left(1)' do
        result = described_class.new(user_id: user.id).call

        labels = result[:by_throw_hand].pluck(:label)
        right_row = result[:by_throw_hand].find { |r| r[:key] == 'right' }
        left_row = result[:by_throw_hand].find { |r| r[:key] == 'left' }

        aggregate_failures do
          # 右投: 右オーバー(4) + 属性なし(2) = 6 PA / 6 AB / 3 hits
          expect(labels).to eq(%w[対右投 対左投])
          expect(right_row).to include(plate_appearances: 6, at_bats: 6, hits: 3, batting_average: 0.5)
          expect(left_row).to include(plate_appearances: 3, at_bats: 3, hits: 1, batting_average: (1.0 / 3).round(3))
        end
      end

      it 'buckets by arm_angle with display_order ascending, unset at tail' do
        result = described_class.new(user_id: user.id).call

        labels = result[:by_arm_angle].pluck(:label)
        over_row = result[:by_arm_angle].find { |r| r[:key] == 1 }
        side_row = result[:by_arm_angle].find { |r| r[:key] == 3 }
        unset_row = result[:by_arm_angle].find { |r| r[:key].nil? }

        aggregate_failures do
          expect(labels).to eq(%w[オーバースロー サイドスロー 未設定])
          expect(over_row).to include(plate_appearances: 4, at_bats: 4, hits: 2, batting_average: 0.5)
          expect(side_row).to include(plate_appearances: 3, at_bats: 3, hits: 1, batting_average: (1.0 / 3).round(3))
          expect(unset_row).to include(plate_appearances: 2, at_bats: 2, hits: 1, batting_average: 0.5)
        end
      end

      it 'buckets by velocity_zone using display_order' do
        result = described_class.new(user_id: user.id).call

        rows = result[:by_velocity_zone]
        aggregate_failures do
          expect(rows.pluck(:label)).to eq(['120-130km/h', '130-140km/h', '未設定'])
          expect(rows[0]).to include(key: 2, at_bats: 3, hits: 1)
          expect(rows[1]).to include(key: 3, at_bats: 4, hits: 2)
          expect(rows.last).to include(key: nil, label: '未設定', at_bats: 2)
        end
      end

      it 'exposes extended stats (TB / BB / HBP / SF / OBP / SLG / OPS / result_counts) per bucket' do
        result = described_class.new(user_id: user.id).call
        right_row = result[:by_throw_hand].find { |r| r[:key] == 'right' }

        aggregate_failures do
          # 右投: 右オーバー(at=4 hit=2 単打2/三振2 → TB=2) + 属性なし(at=2 hit=1 単打1/三振1 → TB=1)
          #   合計: PA=6 AB=6 H=3 TB=3 BB=0 HBP=0 SF=0
          expect(right_row).to include(
            total_bases: 3, base_on_balls: 0, hit_by_pitch: 0, sacrifice_fly: 0
          )
          # OBP = (3+0+0)/(6+0+0+0) = .500, SLG = 3/6 = .500, OPS = 1.000
          expect(right_row[:on_base_percentage]).to eq(0.5)
          expect(right_row[:slugging_percentage]).to eq(0.5)
          expect(right_row[:ops]).to eq(1.0)
          # result_counts は plate_result_id 昇順
          expect(right_row[:result_counts]).to be_an(Array)
          expect(right_row[:result_counts].first).to include(:plate_result_id, :plate_result_name, :count)
        end
      end

      it 'buckets by pitcher_style using display_order' do
        result = described_class.new(user_id: user.id).call

        rows = result[:by_pitcher_style]
        aggregate_failures do
          expect(rows.pluck(:label)).to eq(%w[本格派 技巧派 未設定])
          expect(rows[0]).to include(key: 1, at_bats: 4, hits: 2)
          expect(rows[1]).to include(key: 2, at_bats: 3, hits: 1)
          expect(rows.last).to include(key: nil, at_bats: 2)
        end
      end
    end

    context 'with year filter' do
      let!(:pitcher) { create_pitcher(name: '対象投手', throw_hand: :right) }

      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create_pa(pitcher_id: pitcher.id, plate_result_id: single_result_id, batter_box_number: 1, game: old_game)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create_pa(pitcher_id: pitcher.id, plate_result_id: double_result_id, batter_box_number: 1, game: new_game)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        right_row = result[:by_throw_hand].find { |r| r[:key] == 'right' }
        expect(right_row).to include(plate_appearances: 1, at_bats: 1, hits: 1)
      end
    end

    context 'when a pitcher record is missing (only orphan PA remains)' do
      let!(:living_pitcher) { create_pitcher(name: '生存投手', throw_hand: :right, arm_angle_id: 1) }

      before do
        # 生存投手 (基準データ)
        2.times { |i| create_pa(pitcher_id: living_pitcher.id, plate_result_id: single_result_id, batter_box_number: i + 1) }

        # 削除済み投手の PA を疑似する: 通常は dependent: :nullify と FK で守られるが、
        # 念のため referential_integrity を一時的に外して orphan PA を作り、
        # Aggregator が「未設定」バケットに混入させないことを保護する。
        pa = create(:plate_appearance, game_result:, user:, batter_box_number: 50,
                                       pitcher_id: living_pitcher.id, plate_result_id: single_result_id,
                                       is_new_format: true)
        PlateAppearance.connection.disable_referential_integrity do
          pa.update_column(:pitcher_id, 999_999) # rubocop:disable Rails/SkipsModelValidations
        end
      end

      it 'excludes PAs whose pitcher record is missing' do
        result = described_class.new(user_id: user.id).call

        # 削除済み投手の PA は throw_hand=null（未設定）に紛れ込まない
        right_row = result[:by_throw_hand].find { |r| r[:key] == 'right' }
        unset_row = result[:by_throw_hand].find { |r| r[:key].nil? }

        aggregate_failures do
          expect(right_row).to include(plate_appearances: 2, at_bats: 2, hits: 2)
          expect(unset_row).to be_nil
        end
      end
    end

    context 'with old-format PAs (is_new_format: false / pitcher_id: nil)' do
      let!(:pitcher) { create_pitcher(name: '対象投手', throw_hand: :left, arm_angle_id: 1) }

      before do
        # 対象 (新仕様)
        2.times { |i| create_pa(pitcher_id: pitcher.id, plate_result_id: single_result_id, batter_box_number: i + 1) }
        # 旧仕様 (除外)
        create(:plate_appearance, game_result:, user:, batter_box_number: 90,
                                  pitcher_id: nil, plate_result_id: single_result_id, is_new_format: false)
      end

      it 'excludes old-format PAs from all buckets' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:by_throw_hand].size).to eq(1)
          expect(result[:by_throw_hand].first).to include(key: 'left', plate_appearances: 2, hits: 2)
        end
      end
    end
  end
end
