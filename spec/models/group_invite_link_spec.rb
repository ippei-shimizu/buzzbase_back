require 'rails_helper'

RSpec.describe GroupInviteLink, type: :model do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  describe 'code generation' do
    it 'auto-generates an 8-character code on create' do
      link = create(:group_invite_link, group:, inviter: user)

      expect(link.code).to be_present
      expect(link.code.length).to eq(8)
    end

    it 'generates codes without ambiguous characters (0, O, 1, I, L)' do
      codes = Array.new(10) { create(:group_invite_link, group: create(:group), inviter: user).code }

      codes.each do |code|
        expect(code).not_to match(/[0O1IL]/)
      end
    end

    it 'generates unique codes' do
      codes = Array.new(5) { create(:group_invite_link, group: create(:group), inviter: user).code }

      expect(codes.uniq.length).to eq(5)
    end
  end

  describe '.active scope' do
    let!(:active_link) { create(:group_invite_link, group:, inviter: user, is_active: true) }
    let!(:inactive_link) { create(:group_invite_link, group: create(:group), inviter: user, is_active: false) }

    it 'returns only active links' do
      expect(described_class.active).to include(active_link)
      expect(described_class.active).not_to include(inactive_link)
    end
  end

  describe 'validations' do
    it 'requires code uniqueness' do
      link1 = create(:group_invite_link, group:, inviter: user)
      link2 = build(:group_invite_link, group: create(:group), inviter: user, code: link1.code)

      expect(link2).not_to be_valid
      expect(link2.errors[:code]).to be_present
    end
  end
end
