require 'rails_helper'

RSpec.describe Stadium, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:prefecture).optional }
    it { is_expected.to belong_to(:created_by_user).class_name('User').optional }
    it { is_expected.to have_many(:match_results).dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:stadium) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    describe '同一都道府県内での name 一意性' do
      let(:prefecture) { Prefecture.create!(name: 'テスト県') }

      it '同じ prefecture_id で同名は登録できない' do
        described_class.create!(name: '東京ドーム', prefecture:)
        duplicate = described_class.new(name: '東京ドーム', prefecture:)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to be_present
      end

      it '異なる prefecture_id では同名でも登録できる' do
        other_prefecture = Prefecture.create!(name: 'もう一つのテスト県')
        described_class.create!(name: '東京ドーム', prefecture:)
        another = described_class.new(name: '東京ドーム', prefecture: other_prefecture)
        expect(another).to be_valid
      end

      it 'prefecture_id が NULL の場合は重複を許容する' do
        described_class.create!(name: '謎の球場', prefecture: nil)
        another = described_class.new(name: '謎の球場', prefecture: nil)
        expect(another).to be_valid
      end
    end
  end
end
