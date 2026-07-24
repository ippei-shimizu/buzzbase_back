require 'rails_helper'

RSpec.describe Season, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:game_results).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:season) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }

    it 'is invalid with a whitespace-only name' do
      season = build(:season, name: '   ')
      expect(season).not_to be_valid
      expect(season.errors[:name]).to be_present
    end

    it 'strips leading/trailing whitespace from name before saving' do
      season = build(:season, name: '  2026年度  ')
      season.valid?
      expect(season.name).to eq('2026年度')
    end
  end
end
