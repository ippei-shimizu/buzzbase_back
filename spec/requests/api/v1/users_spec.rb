require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  describe 'PUT /api/v1/user' do
    let(:user) { create(:user, user_id: 'original_id') }

    context 'when not authenticated' do
      it 'returns 401' do
        put '/api/v1/user', params: { user: { user_id: 'whatever' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a valid new user_id' do
      it 'updates and returns success' do
        put '/api/v1/user',
            params: { user: { user_id: 'new_player' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('success' => true)
        expect(user.reload.user_id).to eq('new_player')
      end
    end

    context 'when user_id is empty string (BUZZBASE-BACKEND-P regression)' do
      it 'normalizes to nil and returns success' do
        put '/api/v1/user',
            params: { user: { user_id: '' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(user.reload.user_id).to be_nil
      end

      it 'allows multiple users to clear their user_id without DB conflict' do
        another = create(:user, user_id: 'another_id')

        put '/api/v1/user', params: { user: { user_id: '' } }, headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)

        put '/api/v1/user', params: { user: { user_id: '' } }, headers: auth_headers_for(another)
        expect(response).to have_http_status(:ok)

        expect(user.reload.user_id).to be_nil
        expect(another.reload.user_id).to be_nil
      end
    end

    context 'when user_id is already taken by another user' do
      it 'returns 422 with the localized error message' do
        create(:user, user_id: 'taken_id')

        put '/api/v1/user',
            params: { user: { user_id: 'taken_id' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include(a_string_including('このユーザーIDは既に使われています'))
      end
    end

    context 'when ActiveRecord::RecordNotUnique is raised at the DB layer (race condition)' do
      it 'rescues to 422 instead of leaking 500' do
        # Devise が返す current_api_v1_user のインスタンスを直接掴めないため any_instance を許可
        allow_any_instance_of(User).to receive(:update).and_raise(ActiveRecord::RecordNotUnique) # rubocop:disable RSpec/AnyInstance

        put '/api/v1/user',
            params: { user: { user_id: 'racing_id' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('このユーザーIDは既に使われています')
      end
    end
  end

  describe 'DELETE /api/v1/user' do
    let(:user) { create(:user) }

    context 'when not authenticated' do
      it 'returns 401' do
        delete '/api/v1/user'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with no related records' do
      it 'destroys the user and returns success' do
        headers = auth_headers_for(user)

        expect do
          delete '/api/v1/user', headers:
        end.to change(User, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('success' => true, 'message' => 'アカウントが削除されました')
        expect(User.exists?(user.id)).to be(false)
      end
    end

    # BUZZBASE-MOBILE-1 (issue #288) リグレッション防止:
    # group_invite_links / group_ranking_snapshots を持つユーザーが
    # PG::ForeignKeyViolation で削除できなかった問題への回帰テスト
    context 'when user has a group invite link as inviter (issue #288 regression)' do
      it 'destroys the user and cascades the invite link' do
        invite_link = create(:group_invite_link, inviter: user)

        delete '/api/v1/user', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(User.exists?(user.id)).to be(false)
        expect(GroupInviteLink.exists?(invite_link.id)).to be(false)
      end
    end

    context 'when user has group ranking snapshots (issue #288 regression)' do
      it 'destroys the user and cascades the snapshots' do
        snapshot = create(:group_ranking_snapshot, user:)

        delete '/api/v1/user', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(User.exists?(user.id)).to be(false)
        expect(GroupRankingSnapshot.exists?(snapshot.id)).to be(false)
      end
    end

    context 'when destroy! raises an unexpected error' do
      it 'returns 500 with a localized message instead of leaking the exception' do
        # Devise が返す current_api_v1_user を直接掴めないため any_instance を許可
        allow_any_instance_of(User).to receive(:destroy!).and_raise(StandardError, 'boom') # rubocop:disable RSpec/AnyInstance

        delete '/api/v1/user', headers: auth_headers_for(user)

        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body).to include(
          'success' => false,
          'error' => a_string_including('アカウントの削除に失敗しました')
        )
      end
    end

    context 'when the user is Pro active' do
      before do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      end

      it 'returns 422 with error: pro_active and does not destroy the user' do
        delete '/api/v1/user', headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to include(
          'success' => false,
          'error' => 'pro_active',
          'message' => 'Pro 加入中のため、先に解約してください'
        )
        expect(User.exists?(user.id)).to be(true)
      end
    end
  end
end
