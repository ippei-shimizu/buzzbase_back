require 'rails_helper'

RSpec.describe CancellationFeedback, type: :model do
  let(:user) { create(:user) }

  describe 'バリデーション' do
    it '最小構成（user + reason）で valid' do
      expect(described_class.new(user:, reason: 'expensive')).to be_valid
    end

    it 'user が無いと invalid' do
      record = described_class.new(reason: 'expensive')
      expect(record).not_to be_valid
      expect(record.errors[:user]).to be_present
    end

    it 'subscription は optional（nil でも valid）' do
      expect(described_class.new(user:, subscription: nil, reason: 'expensive')).to be_valid
    end

    it 'reason が nil だと invalid' do
      record = described_class.new(user:, reason: nil)
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    described_class::REASONS.each do |valid_reason|
      it "reason: #{valid_reason} は valid" do
        expect(described_class.new(user:, reason: valid_reason)).to be_valid
      end
    end

    it '範囲外の reason は ArgumentError（enum 仕様）' do
      expect { described_class.new(user:, reason: 'invalid_value') }
        .to raise_error(ArgumentError)
    end

    it 'note が 1000 文字なら valid' do
      record = described_class.new(user:, reason: 'other', note: 'a' * 1000)
      expect(record).to be_valid
    end

    it 'note が 1001 文字だと invalid' do
      record = described_class.new(user:, reason: 'other', note: 'a' * 1001)
      expect(record).not_to be_valid
      expect(record.errors[:note]).to be_present
    end

    it 'note が nil でも valid（任意項目）' do
      expect(described_class.new(user:, reason: 'expensive', note: nil)).to be_valid
    end
  end

  describe 'enum predicate' do
    it 'reason_expensive? が true / false を返す' do
      feedback = described_class.new(user:, reason: 'expensive')
      expect(feedback.reason_expensive?).to be(true)
      expect(feedback.reason_other?).to be(false)
    end
  end

  describe '関連' do
    it 'user に belongs_to' do
      feedback = create(:cancellation_feedback, user:)
      expect(feedback.user).to eq(user)
    end

    it 'subscription は optional（nil 許容）' do
      feedback = described_class.create!(user:, subscription: nil, reason: 'other')
      expect(feedback).to be_persisted
      expect(feedback.subscription).to be_nil
    end
  end
end
