require 'rails_helper'

RSpec.describe 'Api::V1::GroupInvitations', type: :request do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  describe 'POST /api/v1/group_invitations/:id/accept_invitation' do
    context 'when a pending invitation exists' do
      let!(:invitation) { create(:group_invitation, user:, group:, state: 'pending') }

      it 'accepts the invitation' do
        post "/api/v1/group_invitations/#{group.id}/accept_invitation", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(invitation.reload.state).to eq('accepted')
      end
    end

    context 'when no invitation exists' do
      it 'returns 404' do
        post "/api/v1/group_invitations/#{group.id}/accept_invitation", headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the free user already belongs to the free limit of groups' do
      let!(:invitation) { create(:group_invitation, user:, group:, state: 'pending') }

      before do
        GroupInvitation.create!(user:, group: create(:group), state: 'accepted', sent_at: Time.current)
      end

      it 'returns 403 and does not accept the invitation' do
        post "/api/v1/group_invitations/#{group.id}/accept_invitation", headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('Pro プランでグループを無制限に作成・参加できます')
        expect(invitation.reload.state).to eq('pending')
      end
    end

    context 'when a Pro user already belongs to a group' do
      let!(:invitation) { create(:group_invitation, user:, group:, state: 'pending') }

      before do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
        GroupInvitation.create!(user:, group: create(:group), state: 'accepted', sent_at: Time.current)
      end

      it 'accepts the invitation' do
        post "/api/v1/group_invitations/#{group.id}/accept_invitation", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(invitation.reload.state).to eq('accepted')
      end
    end
  end
end
