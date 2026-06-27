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
      expect(described_class.count).to be >= 19
    end

    it '既存IDの意味が維持されている（mobile/constants/battingData.ts と完全一致）' do
      expected = {
        1 => 'ゴロ', 2 => 'フライ', 3 => 'ファールフライ', 4 => 'ライナー', 5 => 'エラー',
        6 => 'フィルダースチョイス', 7 => 'ヒット', 8 => '二塁打', 9 => '三塁打', 10 => '本塁打',
        11 => '犠打', 12 => '犠飛', 13 => '三振', 14 => '振り逃げ', 15 => '四球',
        16 => '死球', 17 => '打撃妨害', 18 => '走塁妨害', 19 => '併殺打'
      }
      aggregate_failures do
        expected.each { |id, name| expect(described_class.find(id).name).to eq(name) }
      end
    end

    it '打数にカウントしない打席結果（四球/死球/犠打/犠飛/打撃妨害/走塁妨害）が正しく区別されている' do
      not_counted = described_class.where(counted_in_at_bats: false).pluck(:name)
      expect(not_counted).to match_array(%w[犠打 犠飛 四球 死球 打撃妨害 走塁妨害])
    end

    it '打球方向が不要な打席結果（三振/振り逃げ/四球/死球/打撃妨害/走塁妨害/併殺打）が正しく区別されている' do
      no_direction = described_class.where(hit_direction_required: false).pluck(:name)
      expect(no_direction).to match_array(%w[三振 振り逃げ 四球 死球 打撃妨害 走塁妨害 併殺打])
    end
  end
end
