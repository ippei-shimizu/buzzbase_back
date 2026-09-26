require 'rails_helper'

RSpec.describe Admin::TeamSerializer, type: :serializer do
  let(:team) { create(:team) }
  let(:serialization) { described_class.new(Team.includes(:users).find(team.id)).as_json }

  describe 'user_name' do
    it 'returns the oldest member who is not soft-deleted' do
      create(:user, name: '退会済みメンバー', team_id: team.id, deleted_at: Time.current)
      create(:user, name: '所属メンバー', team_id: team.id)

      expect(serialization[:user_name]).to eq('所属メンバー')
    end

    it 'returns nil without members' do
      expect(serialization[:user_name]).to be_nil
    end
  end
end
