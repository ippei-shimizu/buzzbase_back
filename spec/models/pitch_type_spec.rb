require 'rails_helper'

RSpec.describe PitchType, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:plate_appearances).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { create(:pitch_type) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:display_order) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe 'seed data' do
    it '10種類の球種が投入されている' do
      expect(described_class.count).to be >= 10
    end

    it '固定IDで投入されている' do
      aggregate_failures do
        expect(described_class.find(1).name).to eq('ストレート系')
        expect(described_class.find(2).name).to eq('ツーシーム系')
        expect(described_class.find(3).name).to eq('カット系')
        expect(described_class.find(4).name).to eq('シュート系')
        expect(described_class.find(5).name).to eq('スライダー系')
        expect(described_class.find(6).name).to eq('カーブ系')
        expect(described_class.find(7).name).to eq('シンカー系')
        expect(described_class.find(8).name).to eq('フォーク系')
        expect(described_class.find(9).name).to eq('スプリット系')
        expect(described_class.find(10).name).to eq('チェンジアップ系')
      end
    end
  end
end
