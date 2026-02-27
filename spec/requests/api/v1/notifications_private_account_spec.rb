require 'rails_helper'

RSpec.describe 'Api::V1::Notifications - Private Account', type: :request do
  let(:private_user) { create(:user, user_id: 'privateuser', is_private: true) }
  let(:requester) { create(:user, user_id: 'requester') }

  describe 'GET /api/v1/notifications' do
    context 'with follow_request notifications' do
      let!(:pending_relationship) { Relationship.create!(follower: requester, followed: private_user, status: :pending) }
      let!(:follow_request_notification) do
        notification = Notification.create!(actor: requester, event_type: 'follow_request', event_id: pending_relationship.id)
        UserNotification.create!(user_id: private_user.id, notification_id: notification.id)
        notification
      end

      it 'includes follow_request notifications with follow_request_id' do
        get '/api/v1/notifications',
            params: { user_id: private_user.user_id },
            headers: auth_headers_for(private_user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        follow_request = json.find { |n| n['event_type'] == 'follow_request' }
        expect(follow_request).to be_present
        expect(follow_request['follow_request_id']).to eq(pending_relationship.id)
      end

      it 'excludes follow_request notifications when the relationship is no longer pending' do
        pending_relationship.accepted!

        get '/api/v1/notifications',
            params: { user_id: private_user.user_id },
            headers: auth_headers_for(private_user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        follow_request = json.find { |n| n['event_type'] == 'follow_request' }
        expect(follow_request).to be_nil
      end
    end

    context 'with follow_request_accepted notifications' do
      it 'includes follow_request_accepted notifications' do
        notification = Notification.create!(actor: private_user, event_type: 'follow_request_accepted', event_id: private_user.id)
        UserNotification.create!(user_id: requester.id, notification_id: notification.id)

        get '/api/v1/notifications',
            params: { user_id: requester.user_id },
            headers: auth_headers_for(requester)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        accepted = json.find { |n| n['event_type'] == 'follow_request_accepted' }
        expect(accepted).to be_present
      end
    end
  end

  describe 'GET /api/v1/notifications/count' do
    it 'includes follow_request in unread count' do
      pending_relationship = Relationship.create!(follower: requester, followed: private_user, status: :pending)
      notification = Notification.create!(actor: requester, event_type: 'follow_request', event_id: pending_relationship.id, read_at: nil)
      UserNotification.create!(user_id: private_user.id, notification_id: notification.id)

      get '/api/v1/notifications/count',
          headers: auth_headers_for(private_user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['count']).to be >= 1
    end

    it 'does not count follow_request if the relationship is no longer pending' do
      relationship = Relationship.create!(follower: requester, followed: private_user, status: :pending)
      notification = Notification.create!(actor: requester, event_type: 'follow_request', event_id: relationship.id, read_at: nil)
      UserNotification.create!(user_id: private_user.id, notification_id: notification.id)

      relationship.accepted!

      get '/api/v1/notifications/count',
          headers: auth_headers_for(private_user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['count']).to eq(0)
    end
  end
end
