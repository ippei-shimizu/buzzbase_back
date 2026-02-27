require 'rails_helper'

RSpec.describe 'Api::V1::Relationships', type: :request do
  let(:user) { create(:user) }
  let(:public_user) { create(:user, is_private: false) }
  let(:private_user) { create(:user, is_private: true) }

  describe 'POST /api/v1/relationships' do
    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/relationships', params: { followed_id: public_user.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when following a public user' do
      it 'creates an accepted relationship and returns follow_status "following"' do
        post '/api/v1/relationships',
             params: { followed_id: public_user.id },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['follow_status']).to eq('following')

        relationship = Relationship.find_by(follower_id: user.id, followed_id: public_user.id)
        expect(relationship.status).to eq('accepted')
      end

      it 'creates a "followed" notification for the target user' do
        expect do
          post '/api/v1/relationships',
               params: { followed_id: public_user.id },
               headers: auth_headers_for(user)
        end.to change(Notification, :count).by(1)
                                           .and change(UserNotification, :count).by(1)

        notification = Notification.last
        expect(notification.event_type).to eq('followed')
        expect(notification.actor_id).to eq(user.id)
      end
    end

    context 'when following a private user' do
      it 'creates a pending relationship and returns follow_status "pending"' do
        post '/api/v1/relationships',
             params: { followed_id: private_user.id },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['follow_status']).to eq('pending')

        relationship = Relationship.find_by(follower_id: user.id, followed_id: private_user.id)
        expect(relationship.status).to eq('pending')
      end

      it 'creates a "follow_request" notification for the private user' do
        post '/api/v1/relationships',
             params: { followed_id: private_user.id },
             headers: auth_headers_for(user)

        notification = Notification.last
        expect(notification.event_type).to eq('follow_request')
        expect(notification.actor_id).to eq(user.id)

        user_notification = UserNotification.last
        expect(user_notification.user_id).to eq(private_user.id)
      end
    end
  end

  describe 'DELETE /api/v1/relationships/:id' do
    context 'when not authenticated' do
      it 'returns 401' do
        delete '/api/v1/relationships/1'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unfollowing an accepted relationship' do
      let!(:relationship) { Relationship.create!(follower: user, followed: public_user, status: :accepted) }

      it 'destroys the relationship' do
        delete "/api/v1/relationships/#{public_user.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(Relationship.find_by(follower_id: user.id, followed_id: public_user.id)).to be_nil
      end
    end

    context 'when canceling a pending follow request' do
      let!(:relationship) { Relationship.create!(follower: user, followed: private_user, status: :pending) }

      it 'destroys the pending relationship' do
        delete "/api/v1/relationships/#{private_user.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(Relationship.find_by(follower_id: user.id, followed_id: private_user.id)).to be_nil
      end
    end
  end

  describe 'POST /api/v1/relationships/:id/accept_follow_request' do
    let(:requester) { create(:user) }
    let!(:pending_relationship) { Relationship.create!(follower: requester, followed: private_user, status: :pending) }

    context 'when not authenticated' do
      it 'returns 401' do
        post "/api/v1/relationships/#{pending_relationship.id}/accept_follow_request"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the private user accepts the request' do
      it 'changes the relationship status to accepted' do
        post "/api/v1/relationships/#{pending_relationship.id}/accept_follow_request",
             headers: auth_headers_for(private_user)

        expect(response).to have_http_status(:ok)
        expect(pending_relationship.reload.status).to eq('accepted')
      end

      it 'creates a "follow_request_accepted" notification for the requester' do
        expect do
          post "/api/v1/relationships/#{pending_relationship.id}/accept_follow_request",
               headers: auth_headers_for(private_user)
        end.to change(Notification, :count).by(1)

        notification = Notification.last
        expect(notification.event_type).to eq('follow_request_accepted')
        expect(notification.actor_id).to eq(private_user.id)

        user_notification = UserNotification.last
        expect(user_notification.user_id).to eq(requester.id)
      end
    end
  end

  describe 'POST /api/v1/relationships/:id/reject_follow_request' do
    let(:requester) { create(:user) }
    let!(:pending_relationship) { Relationship.create!(follower: requester, followed: private_user, status: :pending) }

    context 'when not authenticated' do
      it 'returns 401' do
        post "/api/v1/relationships/#{pending_relationship.id}/reject_follow_request"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the private user rejects the request' do
      it 'destroys the relationship silently' do
        post "/api/v1/relationships/#{pending_relationship.id}/reject_follow_request",
             headers: auth_headers_for(private_user)

        expect(response).to have_http_status(:ok)
        expect(Relationship.find_by(id: pending_relationship.id)).to be_nil
      end

      it 'does not create a notification for the requester' do
        expect do
          post "/api/v1/relationships/#{pending_relationship.id}/reject_follow_request",
               headers: auth_headers_for(private_user)
        end.not_to change(Notification, :count)
      end
    end
  end
end
