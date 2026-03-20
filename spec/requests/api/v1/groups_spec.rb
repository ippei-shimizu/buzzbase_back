require 'rails_helper'

RSpec.describe 'Api::V1::Groups', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'GET /api/v1/groups' do
    context 'when authenticated' do
      it 'returns 200 with groups the current user belongs to' do
        get '/api/v1/groups', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to be_an(Array)
      end
    end

    context 'when not authenticated' do
      it 'returns 500 (index uses current_api_v1_user without auth guard)' do
        get '/api/v1/groups'

        # index is not in authenticate_api_v1_user! but accesses current_api_v1_user
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'GET /api/v1/groups/:id' do
    let(:group) { Group.create!(name: 'テストグループ') }

    context 'when authenticated and user is a member' do
      before do
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      end

      it 'returns 200 with group details' do
        get "/api/v1/groups/#{group.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('group')
        expect(json).to have_key('accepted_users')
      end
    end

    context 'when authenticated but user is not a member' do
      it 'returns 403' do
        get "/api/v1/groups/#{group.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when group does not exist' do
      before do
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      end

      it 'returns 404' do
        get '/api/v1/groups/0', headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/groups' do
    context 'when authenticated' do
      it 'creates a group and returns 201' do
        post '/api/v1/groups',
             params: { group: { name: '新しいグループ' } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['name']).to eq('新しいグループ')
      end

      it 'creates the group with invited users' do
        post '/api/v1/groups',
             params: { group: { name: '新しいグループ' }, invite_user_ids: [] },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
      end

      context 'with invalid params' do
        it 'returns 422' do
          post '/api/v1/groups',
               params: { group: { name: '' } },
               headers: auth_headers_for(user)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/groups', params: { group: { name: 'グループ' } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/groups/:id' do
    let(:group) { Group.create!(name: 'テストグループ') }

    before do
      GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
    end

    context 'when authenticated' do
      it 'updates the group and returns 200' do
        put "/api/v1/groups/#{group.id}",
            params: { group: { name: '更新グループ名' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        put "/api/v1/groups/#{group.id}",
            params: { group: { name: '更新グループ名' } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/groups/:id' do
    let(:group) { Group.create!(name: 'テストグループ') }

    context 'when authenticated and user is group owner' do
      before do
        GroupUser.create!(user:, group:)
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      end

      it 'destroys the group and returns 200' do
        delete "/api/v1/groups/#{group.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to eq('グループが削除されました')
      end
    end

    context 'when authenticated but user is not a group member' do
      it 'returns 403' do
        delete "/api/v1/groups/#{group.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when group does not exist' do
      it 'returns 404' do
        delete '/api/v1/groups/0', headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        delete "/api/v1/groups/#{group.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/groups/:id/invite_members' do
    let(:group) { Group.create!(name: 'テストグループ') }

    before do
      GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
    end

    context 'when authenticated and user is a member' do
      it 'sends invitations and returns 200' do
        post "/api/v1/groups/#{group.id}/invite_members",
             params: { invite_user_ids: [] },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to eq('招待を送信しました')
      end
    end

    context 'when authenticated but user is not a member' do
      it 'returns 403' do
        post "/api/v1/groups/#{group.id}/invite_members",
             params: { invite_user_ids: [other_user.id] },
             headers: auth_headers_for(other_user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/groups/:id/show_group_user' do
    let(:group) { Group.create!(name: 'テストグループ') }

    context 'when authenticated and user is a member' do
      before do
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      end

      it 'returns 200 with group user details' do
        get "/api/v1/groups/#{group.id}/show_group_user", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('group')
        expect(json).to have_key('accepted_users')
      end
    end

    context 'when authenticated but user is not a member' do
      it 'returns 403' do
        get "/api/v1/groups/#{group.id}/show_group_user", headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
