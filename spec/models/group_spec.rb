require 'rails_helper'

RSpec.describe Group, type: :model do
  describe 'associations' do
    it { should have_many(:group_users).dependent(:destroy) }
    it { should have_many(:users).through(:group_users) }
    it { should have_many(:group_invitations).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe '#accepted_users' do
    let(:group) { create(:group) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:group_invitation, group:, user: user1, state: 'accepted')
      create(:group_invitation, group:, user: user2, state: 'pending')
    end

    it 'acceptedのユーザーのみを返す' do
      expect(group.accepted_users).to include(user1)
      expect(group.accepted_users).not_to include(user2)
    end
  end

  describe '#update_users_by_ids' do
    let(:group) { create(:group) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    context '新しいユーザーIDを渡した場合' do
      it '招待レコードを作成してユーザーを返す' do
        invited = group.update_users_by_ids([user1.id])
        expect(invited).to include(user1)
        expect(group.group_invitations.where(user_id: user1.id, state: 'pending').count).to eq(1)
      end
    end

    context '既存のacceptedユーザーを除外した場合' do
      before do
        create(:group_invitation, group:, user: user1, state: 'accepted')
      end

      it '招待レコードを削除する' do
        group.update_users_by_ids([])
        expect(group.group_invitations.where(user_id: user1.id).count).to eq(0)
      end
    end

    context '既存の招待済みユーザーを再度渡した場合' do
      before do
        create(:group_invitation, group:, user: user1, state: 'pending')
      end

      it '重複して招待しない' do
        invited = group.update_users_by_ids([user1.id])
        expect(invited).not_to include(user1)
        expect(group.group_invitations.where(user_id: user1.id).count).to eq(1)
      end
    end
  end
end
