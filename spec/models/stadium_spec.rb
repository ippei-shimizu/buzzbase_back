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

  describe '.find_or_create_for!' do
    let(:prefecture) { Prefecture.create!(name: 'テスト県') }
    let(:user) { create(:user) }

    it '該当が無ければ作成して作成者を記録する' do
      stadium = nil
      expect do
        stadium = described_class.find_or_create_for!(name: '神宮球場', prefecture_id: nil, created_by_user: user)
      end.to change(described_class, :count).by(1)

      aggregate_failures do
        expect(stadium.name).to eq('神宮球場')
        expect(stadium.created_by_user).to eq(user)
      end
    end

    it '同一 prefecture の同名なら作成せず既存を返す' do
      existing = described_class.create!(name: '神宮球場', prefecture:)

      aggregate_failures do
        expect do
          described_class.find_or_create_for!(name: '神宮球場', prefecture_id: prefecture.id, created_by_user: user)
        end.not_to change(described_class, :count)
        expect(
          described_class.find_or_create_for!(name: '神宮球場', prefecture_id: prefecture.id, created_by_user: user)
        ).to eq(existing)
      end
    end

    it '既存を返すときは作成者を上書きしない' do
      creator = create(:user)
      existing = described_class.create!(name: '神宮球場', prefecture:, created_by_user: creator)

      described_class.find_or_create_for!(name: '神宮球場', prefecture_id: prefecture.id, created_by_user: user)

      expect(existing.reload.created_by_user).to eq(creator)
    end

    it '大文字小文字が違っても既存を返す' do
      existing = described_class.create!(name: 'ZOZOマリンスタジアム', prefecture:)

      expect(
        described_class.find_or_create_for!(name: 'zozoマリンスタジアム', prefecture_id: prefecture.id)
      ).to eq(existing)
    end

    it '前後の空白違いでも既存を引き当てる' do
      existing = described_class.create!(name: '神宮球場', prefecture: nil)

      expect(described_class.find_or_create_for!(name: '  神宮球場　', prefecture_id: nil)).to eq(existing)
    end

    it 'prefecture_id が nil 同士なら既存を返す' do
      existing = described_class.create!(name: '市民球場', prefecture: nil)

      expect(described_class.find_or_create_for!(name: '市民球場', prefecture_id: nil)).to eq(existing)
    end

    it 'prefecture 付きの既存は prefecture_id が nil のリクエストでは引き当てず別レコードを作る' do
      existing = described_class.create!(name: '市民球場', prefecture:)

      expect(described_class.find_or_create_for!(name: '市民球場', prefecture_id: nil)).not_to eq(existing)
    end

    it 'name が空なら RecordInvalid を投げる' do
      expect do
        described_class.find_or_create_for!(name: '  ', prefecture_id: nil)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    context 'INSERT が一意制約に負けたとき' do
      it '勝者の既存レコードを返す' do
        winner = described_class.create!(name: '競合テスト球場', prefecture:)
        # SELECT の後・INSERT の前に勝者がコミットした敗者側を再現する。
        allow(described_class).to receive(:find_by_normalized_name).and_return(nil, winner)
        allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        expect(
          described_class.find_or_create_for!(name: '競合テスト球場', prefecture_id: prefecture.id)
        ).to eq(winner)
      end

      it '勝者を引き直せない場合は例外をそのまま投げる' do
        allow(described_class).to receive(:find_by_normalized_name).and_return(nil)
        allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        expect do
          described_class.find_or_create_for!(name: '競合テスト球場', prefecture_id: prefecture.id)
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
