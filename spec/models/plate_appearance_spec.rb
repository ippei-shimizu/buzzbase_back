require 'rails_helper'

RSpec.describe PlateAppearance, type: :model do
  describe 'associations' do
    it { should belong_to(:game_result) }
    it { should belong_to(:user) }
    it { should belong_to(:plate_result).optional }
    it { should belong_to(:contact_quality).optional }
    it { should belong_to(:timing).optional }
    it { should belong_to(:pitch_type).optional }
  end

  describe 'enums' do
    it 'out_type に NPB 準拠のアウト種別を持つ' do
      expect(described_class.out_types).to eq(
        'ground_ball' => 0,
        'fly_ball' => 1,
        'line_drive' => 2,
        'double_play' => 3,
        'foul_fly' => 4
      )
    end

    it 'hit_type に単打/二塁打/三塁打/本塁打を持つ' do
      expect(described_class.hit_types).to eq(
        'single' => 0,
        'double' => 1,
        'triple' => 2,
        'home_run' => 3
      )
    end

    it 'runners_state が 0=無走者〜7=満塁 の8通り' do
      expect(described_class.runners_states).to eq(
        'no_runner' => 0,
        'first' => 1,
        'second' => 2,
        'third' => 3,
        'first_second' => 4,
        'first_third' => 5,
        'second_third' => 6,
        'bases_loaded' => 7
      )
    end
  end

  describe '新カラムの保存と取得' do
    let(:pa) { create(:plate_appearance) }

    it '打撃結果詳細を保存できる' do
      pa.update!(out_type: :ground_ball, hit_type: nil, rbi: 1, run_scored: 0, stolen_bases: 0, caught_stealing: 0)
      pa.reload
      expect(pa.out_type).to eq('ground_ball')
      expect(pa.rbi).to eq(1)
    end

    it '打席状況を保存できる' do
      pa.update!(final_balls: 2, final_strikes: 2, final_outs: 1, first_pitch_swing: false, runners_state: :second, inning: 7)
      pa.reload
      expect(pa.runners_state).to eq('second')
      expect(pa.final_balls).to eq(2)
    end

    it '正規化座標を decimal で保存できる（0.000〜1.000）' do
      pa.update!(hit_location_x: 0.512, hit_location_y: 0.443)
      pa.reload
      expect(pa.hit_location_x).to eq(0.512)
      expect(pa.hit_location_y).to eq(0.443)
    end

    it '自己分析メモ・対戦相手メモを保存できる' do
      pa.update!(self_analysis_memo: '差し込まれた', opponent_memo: '右投げ、変化球多め')
      pa.reload
      expect(pa.self_analysis_memo).to eq('差し込まれた')
      expect(pa.opponent_memo).to eq('右投げ、変化球多め')
    end
  end

  describe 'hit_direction_id の範囲バリデーション' do
    let(:plate_appearance) { build(:plate_appearance) }

    it '1〜13 の範囲内は valid' do
      plate_appearance.hit_direction_id = 10
      expect(plate_appearance).to be_valid
    end

    it 'nil は valid（打席方向なし結果に対応）' do
      plate_appearance.hit_direction_id = nil
      expect(plate_appearance).to be_valid
    end

    it '範囲外（0）は invalid' do
      plate_appearance.hit_direction_id = 0
      expect(plate_appearance).not_to be_valid
      expect(plate_appearance.errors[:hit_direction_id]).to be_present
    end

    it '範囲外（14）は invalid' do
      plate_appearance.hit_direction_id = 14
      expect(plate_appearance).not_to be_valid
      expect(plate_appearance.errors[:hit_direction_id]).to be_present
    end
  end

  describe 'hit_location の範囲バリデーション' do
    let(:pa) { build(:plate_appearance) }

    it '0.0〜1.0 の範囲内は valid' do
      pa.assign_attributes(hit_location_x: 0.5, hit_location_y: 0.0)
      expect(pa).to be_valid
    end

    it '範囲外（負値）は invalid' do
      pa.assign_attributes(hit_location_x: -0.1, hit_location_y: 0.5)
      expect(pa).not_to be_valid
      expect(pa.errors[:hit_location_x]).to be_present
    end

    it '範囲外（1超過）は invalid' do
      pa.assign_attributes(hit_location_x: 0.5, hit_location_y: 1.5)
      expect(pa).not_to be_valid
      expect(pa.errors[:hit_location_y]).to be_present
    end

    it 'nil は valid（既存レコード互換）' do
      pa.assign_attributes(hit_location_x: nil, hit_location_y: nil)
      expect(pa).to be_valid
    end
  end

  describe 'is_new_format フラグ' do
    it 'デフォルトは false' do
      plate_appearance = create(:plate_appearance)
      expect(plate_appearance.is_new_format).to be(false)
    end

    it 'true でセット可能' do
      plate_appearance = create(:plate_appearance, is_new_format: true)
      expect(plate_appearance.is_new_format).to be(true)
    end

    it '既存レコード（旧仕様）は false のまま残る' do
      plate_appearance = create(:plate_appearance)
      plate_appearance.reload
      expect(plate_appearance.is_new_format).to be(false)
    end
  end
end
