require 'rails_helper'

RSpec.describe PlateResult, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:plate_appearances).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { create(:plate_result) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:display_order) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe 'seed data' do
    it '19種類の打席結果が投入されている' do
      expect(PlateResult.count).to be >= 19
    end

    it '既存IDの意味が維持されている（mobile/constants/battingData.ts と完全一致）' do
      expect(PlateResult.find(1).name).to eq('ゴロ')
      expect(PlateResult.find(2).name).to eq('フライ')
      expect(PlateResult.find(3).name).to eq('ファールフライ')
      expect(PlateResult.find(4).name).to eq('ライナー')
      expect(PlateResult.find(5).name).to eq('エラー')
      expect(PlateResult.find(6).name).to eq('フィルダースチョイス')
      expect(PlateResult.find(7).name).to eq('ヒット')
      expect(PlateResult.find(8).name).to eq('二塁打')
      expect(PlateResult.find(9).name).to eq('三塁打')
      expect(PlateResult.find(10).name).to eq('本塁打')
      expect(PlateResult.find(11).name).to eq('犠打')
      expect(PlateResult.find(12).name).to eq('犠飛')
      expect(PlateResult.find(13).name).to eq('三振')
      expect(PlateResult.find(14).name).to eq('振り逃げ')
      expect(PlateResult.find(15).name).to eq('四球')
      expect(PlateResult.find(16).name).to eq('死球')
      expect(PlateResult.find(17).name).to eq('打撃妨害')
      expect(PlateResult.find(18).name).to eq('走塁妨害')
      expect(PlateResult.find(19).name).to eq('併殺打')
    end

    it '打数にカウントしない打席結果（四球/死球/犠打/犠飛/打撃妨害/走塁妨害）が正しく区別されている' do
      not_counted = PlateResult.where(counted_in_at_bats: false).pluck(:name)
      expect(not_counted).to match_array(%w[犠打 犠飛 四球 死球 打撃妨害 走塁妨害])
    end

    it '打球方向が不要な打席結果（三振/振り逃げ/四球/死球/打撃妨害/走塁妨害/併殺打）が正しく区別されている' do
      no_direction = PlateResult.where(hit_direction_required: false).pluck(:name)
      expect(no_direction).to match_array(%w[三振 振り逃げ 四球 死球 打撃妨害 走塁妨害 併殺打])
    end
  end
end
