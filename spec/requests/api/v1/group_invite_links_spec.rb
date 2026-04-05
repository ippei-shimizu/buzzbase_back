require 'rails_helper'

RSpec.describe 'Api::V1::GroupInviteLinks', type: :request do
  let(:inviter) { create(:user) }
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    GroupInvitation.create!(user: inviter, group:, state: 'accepted', sent_at: Time.current)
  end

  describe 'GET /api/v1/invite_links/:code' do
    let!(:invite_link) { create(:group_invite_link, group:, inviter:) }

    context 'when not authenticated' do
      it 'returns 401' do
        get "/api/v1/invite_links/#{invite_link.code}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when code is valid' do
      it 'returns group and inviter info' do
        get "/api/v1/invite_links/#{invite_link.code}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['group']['id']).to eq(group.id)
        expect(json['group']['name']).to eq(group.name)
        expect(json['group']['member_count']).to eq(1) # inviter only
        expect(json['inviter']['name']).to eq(inviter.name)
      end
    end

    context 'when code does not exist' do
      it 'returns 404' do
        get '/api/v1/invite_links/INVALID1', headers: auth_headers_for(user)
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq('無効な招待コードです')
      end
    end

    context 'when code is inactive' do
      before { invite_link.update!(is_active: false) }

      it 'returns 404' do
        get "/api/v1/invite_links/#{invite_link.code}", headers: auth_headers_for(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/invite_links/:code/accept' do
    let!(:invite_link) { create(:group_invite_link, group:, inviter:) }

    context 'when not authenticated' do
      it 'returns 401' do
        post "/api/v1/invite_links/#{invite_link.code}/accept"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when code is valid' do
      before do
        allow(PushNotificationService).to receive(:send_to_user)
      end

      it 'creates group invitation with accepted state' do
        expect do
          post "/api/v1/invite_links/#{invite_link.code}/accept", headers: auth_headers_for(user)
        end.to change(GroupInvitation, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['group_id']).to eq(group.id)

        invitation = GroupInvitation.find_by(user:, group:)
        expect(invitation.state).to eq('accepted')
      end

      it 'creates mutual follow relationships' do
        expect do
          post "/api/v1/invite_links/#{invite_link.code}/accept", headers: auth_headers_for(user)
        end.to change(Relationship, :count).by(2)

        expect(user.following?(inviter)).to be true
        expect(inviter.following?(user)).to be true
      end

      it 'creates mutual follow with accepted status even for private accounts' do
        inviter.update!(is_private: true)
        user.update!(is_private: true)

        post "/api/v1/invite_links/#{invite_link.code}/accept", headers: auth_headers_for(user)

        expect(user.reload.following?(inviter)).to be true
        expect(inviter.reload.following?(user)).to be true
      end

      it 'creates notification for inviter' do
        expect do
          post "/api/v1/invite_links/#{invite_link.code}/accept", headers: auth_headers_for(user)
        end.to change(Notification, :count).by(1)
                                           .and change(UserNotification, :count).by(1)

        notification = Notification.last
        expect(notification.actor_id).to eq(user.id)
        expect(notification.event_type).to eq('group_invitation')
        expect(notification.event_id).to eq(group.id)
      end

      it 'does not create duplicate follow if already following' do
        user.follow(inviter)

        # only inviter -> user
        expect do
          post "/api/v1/invite_links/#{invite_link.code}/accept", headers: auth_headers_for(user)
        end.to change(Relationship, :count).by(1)
        expect(inviter.following?(user)).to be true
      end
    end

    context 'when user is already a member' do
      before do
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      end

      it 'returns 422' do
        post "/api/v1/invite_links/#{invite_link.code}/accept", headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('既にこのグループのメンバーです')
      end
    end

    context 'when code does not exist' do
      it 'returns 404' do
        post '/api/v1/invite_links/INVALID1/accept', headers: auth_headers_for(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
