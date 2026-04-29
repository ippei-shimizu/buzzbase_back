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
end
