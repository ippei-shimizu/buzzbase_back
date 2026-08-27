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

  describe 'name の正規化' do
    it '前後のスペースを取り除いて保存する' do
      expect(described_class.create!(name: '  神宮球場  ').name).to eq('神宮球場')
    end

    it '全角スペースも取り除いて保存する' do
      expect(described_class.create!(name: '　神宮球場　').name).to eq('神宮球場')
    end
  end

  describe '.find_or_initialize_for' do
    let(:prefecture) { Prefecture.create!(name: 'テスト県') }

    it '該当が無ければ未保存の新規インスタンスを返す' do
      stadium = described_class.find_or_initialize_for(name: '神宮球場', prefecture_id: nil)

      aggregate_failures do
        expect(stadium).not_to be_persisted
        expect(stadium.name).to eq('神宮球場')
      end
    end

    it '同一 prefecture の同名なら既存を返す' do
      existing = described_class.create!(name: '神宮球場', prefecture:)

      expect(described_class.find_or_initialize_for(name: '神宮球場', prefecture_id: prefecture.id)).to eq(existing)
    end

    it '大文字小文字が違っても既存を返す' do
      existing = described_class.create!(name: 'ZOZOマリンスタジアム', prefecture:)

      expect(
        described_class.find_or_initialize_for(name: 'zozoマリンスタジアム', prefecture_id: prefecture.id)
      ).to eq(existing)
    end

    it '前後の空白違いでも既存を引き当てる' do
      existing = described_class.create!(name: '神宮球場', prefecture: nil)

      expect(described_class.find_or_initialize_for(name: '  神宮球場　', prefecture_id: nil)).to eq(existing)
    end

    it 'prefecture_id が nil 同士なら既存を返す' do
      existing = described_class.create!(name: '市民球場', prefecture: nil)

      expect(described_class.find_or_initialize_for(name: '市民球場', prefecture_id: nil)).to eq(existing)
    end

    it 'prefecture 付きの既存は prefecture_id が nil のリクエストでは引き当てない' do
      described_class.create!(name: '市民球場', prefecture:)

      expect(described_class.find_or_initialize_for(name: '市民球場', prefecture_id: nil)).not_to be_persisted
    end
  end
end
