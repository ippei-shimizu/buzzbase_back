require 'rails_helper'

# 試合記録アップデート（issue #330）で導入したマスタテーブル群のシードが
# 「既存 plate_appearances の _id 値の意味を不変に保つ」ことと
# 「複数回適用しても重複しない」ことを担保する。
RSpec.describe 'マスタシードの不変性と冪等性', type: :model do
  describe 'mobile/constants/battingData.ts と plate_results の ID/name の完全一致' do
    it 'ファールフライ = 3' do
      expect(PlateResult.find(3).name).to eq('ファールフライ')
    end

    it '走塁妨害 = 18' do
      expect(PlateResult.find(18).name).to eq('走塁妨害')
    end

    it '併殺打 = 19' do
      expect(PlateResult.find(19).name).to eq('併殺打')
    end

    it 'ヒット = 7（既存集計の単打判定で使用）' do
      expect(PlateResult.find(7).name).to eq('ヒット')
    end

    it '三振 = 13（既存集計の三振判定で使用）' do
      expect(PlateResult.find(13).name).to eq('三振')
    end
  end

  describe '冪等性' do
    it 'MasterData::Seeder.from_yaml を再実行しても件数が増えない' do
      before_count = PitchType.count
      MasterData::Seeder.from_yaml(ActiveRecord::Base.connection, table: 'pitch_types', file: 'pitch_types.yml')
      expect(PitchType.count).to eq(before_count)
    end

    it 'MasterData::Seeder.from_yaml を再実行しても name が変わらない' do
      before_names = PitchType.order(:id).pluck(:id, :name)
      MasterData::Seeder.from_yaml(ActiveRecord::Base.connection, table: 'pitch_types', file: 'pitch_types.yml')
      after_names = PitchType.order(:id).pluck(:id, :name)
      expect(after_names).to eq(before_names)
    end
  end

  describe 'シーケンス整合性' do
    it 'マスタ投入後にユーザー追加（stadiums）を行っても ID 衝突しない' do
      user = create(:user)
      stadium = Stadium.create!(name: '東京ドーム', created_by_user: user)
      expect(stadium.id).to be_present
      expect(Stadium.find(stadium.id).name).to eq('東京ドーム')
    end
  end
end
