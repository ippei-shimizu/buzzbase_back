require 'rails_helper'

RSpec.describe Admin::Analytics::UsersService do
  describe '#call' do
    let(:team) { create(:team, name: 'BUZZ学園') }
    let!(:member) { create(:user, team_id: team.id) }
    let!(:unaffiliated_user) { create(:user, team_id: nil) }

    it 'returns the team name of each user' do
      users = described_class.new({}).call[:users]

      expect(users.find { |user| user[:id] == member.id }[:team_name]).to eq('BUZZ学園')
      expect(users.find { |user| user[:id] == unaffiliated_user.id }[:team_name]).to be_nil
    end

    it 'excludes soft-deleted users' do
      deleted_user = create(:user, deleted_at: Time.current)

      result = described_class.new({}).call

      expect(result[:users].pluck(:id)).not_to include(deleted_user.id)
      expect(result[:total_count]).to eq(2)
    end
  end
end
