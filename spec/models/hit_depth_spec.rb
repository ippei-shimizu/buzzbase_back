require 'rails_helper'

RSpec.describe HitDepth, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:plate_appearances).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { create(:hit_depth) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:display_order) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe 'seed data' do
    it '3種類の打球の深さが投入されている' do
      expect(described_class.count).to be >= 3
    end

    it '固定IDで投入されている' do
      expect(described_class.find(1).name).to eq('内野')
      expect(described_class.find(2).name).to eq('外野')
      expect(described_class.find(3).name).to eq('フェンス際')
    end
  end
end
