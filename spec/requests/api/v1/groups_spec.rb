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
      it 'returns unauthorized' do
        get '/api/v1/groups'

        expect(response).to have_http_status(:unauthorized)
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

    context 'when the free user already belongs to the free limit of groups' do
      before do
        GroupInvitation.create!(user:, group: Group.create!(name: '既存グループ'), state: 'accepted', sent_at: Time.current)
      end

      it 'returns 403 and does not create the group' do
        expect do
          post '/api/v1/groups',
               params: { group: { name: '2つ目のグループ' } },
               headers: auth_headers_for(user)
        end.not_to change(Group, :count)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('group_limit_exceeded')
        expect(response.parsed_body['message']).to eq('Pro プランでグループを無制限に作成・参加できます')
      end
    end

    context 'when a Pro user already belongs to a group' do
      before do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
        GroupInvitation.create!(user:, group: Group.create!(name: '既存グループ'), state: 'accepted', sent_at: Time.current)
      end

      it 'creates the group and returns 201' do
        post '/api/v1/groups',
             params: { group: { name: '2つ目のグループ' } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
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

      it 'enqueues a push notification job for each invited user instead of sending synchronously' do
        user.follow(other_user)

        expect do
          post "/api/v1/groups/#{group.id}/invite_members",
               params: { invite_user_ids: [other_user.id] },
               headers: auth_headers_for(user)
        end.to have_enqueued_job(PushNotificationJob)
          .with(other_user.id, title: 'BUZZ BASE', body: "#{user.name}さんからグループに招待されました")
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

  describe 'POST /api/v1/groups/:id/invite_link' do
    let(:group) { Group.create!(name: 'テストグループ') }

    context 'when not authenticated' do
      it 'returns 401' do
        post "/api/v1/groups/#{group.id}/invite_link"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated and user is a member' do
      before do
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      end

      it 'creates an invite link and returns the code' do
        post "/api/v1/groups/#{group.id}/invite_link", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['code']).to be_present
        expect(json['code'].length).to eq(8)
        expect(json['group_name']).to eq('テストグループ')
        expect(json['group_id']).to eq(group.id)
      end

      it 'returns the same code on subsequent calls' do
        post "/api/v1/groups/#{group.id}/invite_link", headers: auth_headers_for(user)
        first_code = response.parsed_body['code']

        post "/api/v1/groups/#{group.id}/invite_link", headers: auth_headers_for(user)
        second_code = response.parsed_body['code']

        expect(first_code).to eq(second_code)
      end
    end

    context 'when authenticated but user is not a member' do
      it 'returns 403' do
        post "/api/v1/groups/#{group.id}/invite_link", headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when group does not exist' do
      it 'returns 404' do
        post '/api/v1/groups/0/invite_link', headers: auth_headers_for(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/groups/:id (with filters)' do
    let(:group) { Group.create!(name: 'テストグループ') }
    let!(:tournament) { create(:tournament, name: '春季大会') }

    before do
      GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
      game_result = create(:game_result, user:)
      game_result.match_result.update!(tournament:)
    end

    it 'returns available_years in response' do
      get "/api/v1/groups/#{group.id}", headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key('available_years')
      expect(json['available_years']).to be_an(Array)
    end

    it 'returns available_tournaments in response' do
      get "/api/v1/groups/#{group.id}", headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key('available_tournaments')
      tournaments = json['available_tournaments']
      expect(tournaments).to be_an(Array)
      expect(tournaments.first['name']).to eq('春季大会')
    end

    it 'tournament_idでフィルタリングできる' do
      get "/api/v1/groups/#{group.id}",
          params: { tournament_id: tournament.id },
          headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['batting_averages']).to be_present
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

  describe 'authentication guard for member-only actions' do
    let(:group) { create(:group) }

    it 'returns unauthorized for GET show_group_user without auth' do
      get "/api/v1/groups/#{group.id}/show_group_user"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for PUT update_group_info without auth' do
      put "/api/v1/groups/#{group.id}/update_group_info", params: { group: { name: '新しい名前' } }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for POST invite_members without auth' do
      post "/api/v1/groups/#{group.id}/invite_members", params: { invite_user_ids: [] }

      expect(response).to have_http_status(:unauthorized)
    end

    # 認証を通過したあとはメンバーシップ判定に落ちる。401 への変更で 403 が消えていないことを担保する。
    it 'returns forbidden for PUT update_group_info when authenticated but not a member' do
      put "/api/v1/groups/#{group.id}/update_group_info",
          params: { group: { name: '新しい名前' } },
          headers: auth_headers_for(user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
