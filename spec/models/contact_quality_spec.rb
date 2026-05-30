require 'rails_helper'

RSpec.describe ContactQuality, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:plate_appearances).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { create(:contact_quality) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:display_order) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe 'seed data' do
    it '5種類の打球の質が投入されている' do
      expect(ContactQuality.count).to be >= 5
    end

    it '固定IDで投入されている' do
      expect(ContactQuality.find(1).name).to eq('真芯')
      expect(ContactQuality.find(2).name).to eq('先っぽ')
      expect(ContactQuality.find(3).name).to eq('詰まり')
      expect(ContactQuality.find(4).name).to eq('擦り')
      expect(ContactQuality.find(5).name).to eq('ドライブ')
    end
  end
end
