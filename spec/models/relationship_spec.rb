require 'rails_helper'

RSpec.describe Relationship, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:follower).class_name('User') }
    it { is_expected.to belong_to(:followed).class_name('User') }
  end

  describe 'enum' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, accepted: 1) }
  end

  describe 'scopes' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    let!(:accepted_rel) { described_class.create!(follower: user1, followed: user2, status: :accepted) }
    let!(:pending_rel) { described_class.create!(follower: user1, followed: user3, status: :pending) }

    describe '.accepted' do
      it 'returns only accepted relationships' do
        expect(described_class.accepted).to include(accepted_rel)
        expect(described_class.accepted).not_to include(pending_rel)
      end
    end

    describe '.pending' do
      it 'returns only pending relationships' do
        expect(described_class.pending).to include(pending_rel)
        expect(described_class.pending).not_to include(accepted_rel)
      end
    end
  end

  describe 'default status' do
    it 'defaults to accepted' do
      user1 = create(:user)
      user2 = create(:user)
      rel = described_class.create!(follower: user1, followed: user2)
      expect(rel.status).to eq('accepted')
    end
  end
end
