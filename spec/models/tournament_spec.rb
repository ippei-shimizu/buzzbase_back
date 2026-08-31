require 'rails_helper'

RSpec.describe Tournament, type: :model do
  describe 'associations' do
    it { should have_many(:match_results).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }

    # 制約を後から追加したため、既に不正な name を持つ行が修復不能にならないことを担保する。
    it 'name を変更しない更新は制約追加前の不正なレコードでも通る' do
      invalid = described_class.new(name: 'a' * 101)
      invalid.save!(validate: false)

      expect(invalid.reload.update(updated_at: Time.current)).to be true
    end

    it 'name を変更する更新は検証される' do
      invalid = described_class.new(name: 'a' * 101)
      invalid.save!(validate: false)

      expect(invalid.reload.update(name: 'b' * 101)).to be false
    end
  end

  describe 'name の正規化' do
    it '前後のスペースを取り除いて保存する' do
      expect(described_class.create!(name: '  春季大会  ').name).to eq('春季大会')
    end

    it '全角スペースも取り除いて保存する' do
      expect(described_class.create!(name: '　春季大会　').name).to eq('春季大会')
    end
  end

  describe '.find_or_initialize_by_name' do
    it '既存が無ければ未保存の新規インスタンスを返す' do
      tournament = described_class.find_or_initialize_by_name('春季大会')

      aggregate_failures do
        expect(tournament).not_to be_persisted
        expect(tournament.name).to eq('春季大会')
      end
    end

    it '既存があれば保存済みの既存を返す' do
      existing = create(:tournament, name: '春季大会')

      expect(described_class.find_or_initialize_by_name('春季大会')).to eq(existing)
    end

    it '同名が複数存在する場合は最小 id のレコードを返す' do
      oldest = create(:tournament, name: '春季大会')
      create(:tournament, name: '春季大会')

      expect(described_class.find_or_initialize_by_name('春季大会')).to eq(oldest)
    end

    it '前後の空白違いでも既存を引き当てる' do
      existing = create(:tournament, name: '春季大会')

      expect(described_class.find_or_initialize_by_name('  春季大会　')).to eq(existing)
    end
  end
end
