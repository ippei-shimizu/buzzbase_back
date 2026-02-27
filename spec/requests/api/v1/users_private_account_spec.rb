require 'rails_helper'

RSpec.describe 'Api::V1::Users - Private Account', type: :request do
  let(:public_user) { create(:user, user_id: 'publicuser', is_private: false) }
  let(:private_user) { create(:user, user_id: 'privateuser', is_private: true) }
  let(:follower) { create(:user, user_id: 'followeruser') }
  let(:non_follower) { create(:user, user_id: 'nonfollower') }

  before do
    Relationship.create!(follower:, followed: private_user, status: :accepted)
  end

  describe 'GET /api/v1/users/show_user_id_data' do
    context 'when viewing a public user' do
      it 'returns full profile data with is_private false' do
        get '/api/v1/users/show_user_id_data', params: { user_id: public_user.user_id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['is_private']).to be false
        expect(json['following_count']).not_to be_nil
        expect(json['followers_count']).not_to be_nil
      end
    end

    context 'when viewing a private user as a follower' do
      it 'returns full profile data' do
        get '/api/v1/users/show_user_id_data',
            params: { user_id: private_user.user_id },
            headers: auth_headers_for(follower)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['is_private']).to be true
        expect(json['follow_status']).to eq('following')
        expect(json['following_count']).not_to be_nil
        expect(json['followers_count']).not_to be_nil
      end
    end

    context 'when viewing a private user as a non-follower' do
      it 'returns minimal profile data with nil counts' do
        get '/api/v1/users/show_user_id_data',
            params: { user_id: private_user.user_id },
            headers: auth_headers_for(non_follower)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['is_private']).to be true
        expect(json['follow_status']).to eq('none')
        expect(json['following_count']).to be_nil
        expect(json['followers_count']).to be_nil
      end
    end

    context 'when viewing a private user without authentication' do
      it 'returns minimal profile data' do
        get '/api/v1/users/show_user_id_data',
            params: { user_id: private_user.user_id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['is_private']).to be true
        expect(json['following_count']).to be_nil
        expect(json['followers_count']).to be_nil
      end
    end
  end

  describe 'GET /api/v1/users/:id/following_users' do
    context 'when viewing a public user' do
      it 'returns the following list' do
        Relationship.create!(follower: public_user, followed: follower, status: :accepted)

        get "/api/v1/users/#{public_user.id}/following_users",
            headers: auth_headers_for(non_follower)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when viewing a private user as a follower' do
      it 'returns the following list' do
        get "/api/v1/users/#{private_user.id}/following_users",
            headers: auth_headers_for(follower)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when viewing a private user as a non-follower' do
      it 'returns 403' do
        get "/api/v1/users/#{private_user.id}/following_users",
            headers: auth_headers_for(non_follower)

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json['error']).to eq('このアカウントは非公開です')
      end
    end
  end

  describe 'GET /api/v1/users/:id/followers_users' do
    context 'when viewing a private user as a follower' do
      it 'returns the followers list' do
        get "/api/v1/users/#{private_user.id}/followers_users",
            headers: auth_headers_for(follower)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when viewing a private user as a non-follower' do
      it 'returns 403' do
        get "/api/v1/users/#{private_user.id}/followers_users",
            headers: auth_headers_for(non_follower)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /api/v1/user (update)' do
    context 'when switching from private to public' do
      let(:private_account) { create(:user, is_private: true) }
      let(:requester1) { create(:user) }
      let(:requester2) { create(:user) }

      before do
        Relationship.create!(follower: requester1, followed: private_account, status: :pending)
        Relationship.create!(follower: requester2, followed: private_account, status: :pending)
      end

      it 'auto-approves all pending follow requests' do
        put '/api/v1/user',
            params: { user: { is_private: false, name: private_account.name } },
            headers: auth_headers_for(private_account)

        expect(response).to have_http_status(:ok)
        expect(Relationship.pending.where(followed_id: private_account.id).count).to eq(0)
        expect(Relationship.accepted.where(followed_id: private_account.id).count).to eq(2)
      end
    end

    context 'when switching from public to private' do
      it 'keeps existing followers as accepted' do
        existing_follower = create(:user)
        Relationship.create!(follower: existing_follower, followed: public_user, status: :accepted)

        put '/api/v1/user',
            params: { user: { is_private: true, name: public_user.name } },
            headers: auth_headers_for(public_user)

        expect(response).to have_http_status(:ok)
        expect(public_user.reload.is_private?).to be true
        expect(Relationship.find_by(follower: existing_follower, followed: public_user).status).to eq('accepted')
      end
    end
  end

  describe 'GET /api/v1/users/search' do
    it 'includes is_private flag in search results' do
      public_user
      private_user

      get '/api/v1/users/search', params: { query: 'user' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      private_result = json.find { |u| u['user_id'] == 'privateuser' }
      public_result = json.find { |u| u['user_id'] == 'publicuser' }
      expect(private_result['is_private']).to be true
      expect(public_result['is_private']).to be false
    end
  end
end
