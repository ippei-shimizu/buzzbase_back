require 'rails_helper'

# 試合記録アップデート（issue #330）のマイグレーション適用後も、
# 既存仕様で記録された plate_appearances / batting_averages の値が
# 「消えない・改変されない」ことを担保する。
#
# 新カラムは全 nullable で追加されるため、既存レコードは NULL のまま残り、
# 既存集計テーブル (batting_averages) は plate_appearances の値を使わずに
# 別途集計済みのため、新カラム追加の影響を受けないことを示す。
RSpec.describe 'マイグレーション後の既存データ保全', type: :model do
  let(:user) { create(:user) }
  # game_result factory の after(:create) で match_result が自動生成されるため、
  # 既存試合の作成は game_result 側から行う。
  let(:game_result) { create(:game_result, user:) }
  let(:match_result) { game_result.match_result }

  describe '既存仕様の plate_appearance を作成すると' do
    let!(:plate_appearance) do
      create(
        :plate_appearance,
        game_result:,
        user:,
        plate_result_id: 7,
        hit_direction_id: 10,
        batting_position_id: 8,
        batting_result: '中安',
        batter_box_number: 1
      )
    end

    it '既存カラムの値が変わらない' do
      plate_appearance.reload
      expect(plate_appearance.plate_result_id).to eq(7)
      expect(plate_appearance.hit_direction_id).to eq(10)
      expect(plate_appearance.batting_position_id).to eq(8)
      expect(plate_appearance.batting_result).to eq('中安')
    end

    it '新カラムは NULL のまま残る' do
      plate_appearance.reload
      new_columns = %i[out_type hit_type rbi run_scored stolen_bases caught_stealing
                       final_balls final_strikes final_outs first_pitch_swing runners_state inning
                       contact_quality_id timing_id pitch_type_id
                       self_analysis_memo opponent_memo hit_location_x hit_location_y]
      aggregate_failures do
        new_columns.each do |column|
          expect(plate_appearance.public_send(column)).to be_nil, "expected #{column} to be nil"
        end
      end
    end
  end

  describe '既存仕様の batting_average を作成すると' do
    let!(:batting_average) do
      create(
        :batting_average,
        game_result:,
        user:,
        at_bats: 3,
        hit: 1,
        two_base_hit: 0,
        three_base_hit: 0,
        home_run: 0,
        total_bases: 1,
        runs_batted_in: 0,
        strike_out: 1,
        base_on_balls: 0,
        hit_by_pitch: 0,
        sacrifice_hit: 0,
        sacrifice_fly: 0,
        stealing_base: 0,
        caught_stealing: 0,
        error: 0
      )
    end

    it '主要集計カラムの値が変わらない' do
      batting_average.reload
      expect(batting_average.at_bats).to eq(3)
      expect(batting_average.hit).to eq(1)
      expect(batting_average.total_bases).to eq(1)
      expect(batting_average.strike_out).to eq(1)
    end

    it 'マイグレーションでカラム構造が変わっていない（新カラムが追加されていない）' do
      expect(BattingAverage.column_names).to include(
        'at_bats', 'hit', 'two_base_hit', 'three_base_hit', 'home_run',
        'total_bases', 'runs_batted_in', 'run', 'strike_out', 'base_on_balls',
        'hit_by_pitch', 'sacrifice_hit', 'sacrifice_fly', 'stealing_base',
        'caught_stealing', 'error'
      )
      # batting_averages テーブルには新カラムを追加していない
      new_columns = %w[out_type hit_type rbi runners_state contact_quality_id]
      expect(BattingAverage.column_names & new_columns).to be_empty
    end
  end

  describe 'match_results.stadium_id を追加しても' do
    let!(:match_result_without_stadium) do
      gr = create(:game_result, user:)
      gr.match_result
    end

    it '既存試合は stadium_id が NULL のまま残る' do
      match_result_without_stadium.reload
      expect(match_result_without_stadium.stadium_id).to be_nil
    end

    it 'optional な関連なのでバリデーションは通る' do
      expect(match_result_without_stadium).to be_valid
    end
  end
end
