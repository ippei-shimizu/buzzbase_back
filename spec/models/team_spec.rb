require 'rails_helper'

RSpec.describe Team, type: :model do
  describe 'associations' do
    it { should belong_to(:category).class_name('BaseballCategory').optional }
    it { should belong_to(:prefecture).optional }
    it { should have_one(:user).dependent(:destroy) }
  end

  describe 'validations' do
    let(:prefecture) { Prefecture.create!(name: '東京都') }
    let(:category) { BaseballCategory.create!(name: '高校生') }

    it { should validate_presence_of(:name) }

    it 'is valid with name only (master ids nil)' do
      team = described_class.new(name: 'テストチーム')
      expect(team).to be_valid
    end

    it 'is valid with name and existing master ids' do
      team = described_class.new(name: 'テストチーム', category_id: category.id, prefecture_id: prefecture.id)
      expect(team).to be_valid
    end

    it 'is invalid with prefecture_id = 0' do
      team = described_class.new(name: 'テスト', prefecture_id: 0)
      expect(team).not_to be_valid
      expect(team.errors[:prefecture_id]).to be_present
    end

    it 'is invalid with category_id = 0' do
      team = described_class.new(name: 'テスト', category_id: 0)
      expect(team).not_to be_valid
      expect(team.errors[:category_id]).to be_present
    end

    it 'is invalid with negative prefecture_id' do
      team = described_class.new(name: 'テスト', prefecture_id: -1)
      expect(team).not_to be_valid
    end

    it 'is invalid when prefecture_id refers to a non-existent record' do
      missing_id = Prefecture.maximum(:id).to_i + 9999
      team = described_class.new(name: 'テスト', prefecture_id: missing_id)
      expect(team).not_to be_valid
      expect(team.errors[:prefecture_id]).to include('は存在しない都道府県です')
    end

    it 'is invalid when category_id refers to a non-existent record' do
      missing_id = BaseballCategory.maximum(:id).to_i + 9999
      team = described_class.new(name: 'テスト', category_id: missing_id)
      expect(team).not_to be_valid
      expect(team.errors[:category_id]).to include('は存在しないカテゴリです')
    end
  end
end
