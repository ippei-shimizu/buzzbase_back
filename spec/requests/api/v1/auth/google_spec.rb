require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Google', type: :request do
  let(:google_uid) { '110000000000000000001' }
  let(:email) { 'google-user@example.com' }
  let(:google_data) { { uid: google_uid, email:, name: '山田 太郎' } }

  before do
    allow(GoogleAuthService).to receive(:verify).and_return(google_data)
  end

  describe 'POST /api/v1/google_sign_in' do
    context '新規ユーザーの場合' do
      it 'ユーザーを作成してログインする' do
        expect do
          post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.headers['access-token']).to be_present
        expect(response.headers['client']).to be_present
        expect(response.headers['uid']).to be_present

        expect(response.parsed_body['requires_username']).to be true
      end

      it 'provider: google で作成されトークンが保存される' do
        post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }

        user = User.last
        expect(user.provider).to eq('google')
        expect(user.uid).to eq(google_uid)
        expect(user.email).to eq(email)
        expect(user.confirmed_at).to be_present
        expect(user.tokens.keys).to include(response.headers['client'])
      end
    end

    context '既存のGoogleユーザーの場合' do
      let!(:existing_user) do
        create(:user, :google, uid: google_uid, email:, user_id: 'yamada')
      end

      it '既存ユーザーでログインする' do
        expect do
          post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['requires_username']).to be false
        expect(existing_user.reload.tokens.keys).to include(response.headers['client'])
      end
    end

    context 'メール登録済みの未確認ユーザーが同じメールでログインする場合' do
      let!(:existing_user) do
        create(:user, :unconfirmed, provider: 'email', uid: email, email:, user_id: 'yamada')
      end

      it 'provider・uid・confirmed_at をまとめて更新しトークンを発行する' do
        post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }

        expect(response).to have_http_status(:ok)

        existing_user.reload
        expect(existing_user.provider).to eq('google')
        expect(existing_user.uid).to eq(google_uid)
        expect(existing_user.confirmed_at).to be_present
        expect(existing_user.tokens.keys).to include(response.headers['client'])
      end
    end

    context 'id_tokenが未指定の場合' do
      it '401を返す' do
        post '/api/v1/google_sign_in', params: {}

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'トークンが無効な場合' do
      before do
        allow(GoogleAuthService).to receive(:verify).and_raise(
          GoogleAuthService::InvalidToken, 'Google IDトークンの検証に失敗しました'
        )
      end

      it '401を返す' do
        post '/api/v1/google_sign_in', params: { id_token: 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['errors']).to include('Google IDトークンの検証に失敗しました')
      end
    end

    context 'アカウントが停止されている場合' do
      let!(:suspended_user) do
        create(:user, :google, uid: google_uid, email:, suspended_at: Time.current)
      end

      it '401を返す' do
        post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['errors']).to include('アカウントが停止されています')
        expect(suspended_user.reload.tokens).to be_empty
      end
    end

    context 'アカウントが削除されている場合' do
      let!(:deleted_user) do
        create(:user, :google, uid: google_uid, email:, deleted_at: Time.current)
      end

      it '401を返す' do
        post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['errors']).to include('アカウントが削除されています')
        expect(deleted_user.reload.tokens).to be_empty
      end
    end

    context 'メールが取得できなかった場合' do
      let(:google_data) { { uid: google_uid, email: nil, name: nil } }

      it '401を返す' do
        post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['errors']).to include('メールアドレスが取得できませんでした')
      end
    end

    context '同一メールのリクエストが並行して一意制約に負けた場合' do
      let!(:winner) { create(:user, :google, uid: google_uid, email:, user_id: 'yamada') }

      before do
        # SELECT の後・INSERT の前に勝者がコミットした敗者側を再現する。
        allow(User).to receive(:find_by).and_call_original
        allow(User).to receive(:find_by).with(provider: 'google', uid: google_uid).and_return(nil, winner)
        allow(User).to receive(:find_by).with(email:).and_return(nil)
        allow(User).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      end

      it '500ではなく勝者のユーザーでサインインさせる' do
        expect do
          post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)
        expect(response.headers['access-token']).to be_present
        expect(winner.reload.tokens.keys).to include(response.headers['client'])
      end
    end

    context 'メールに大文字・前後の空白が含まれる場合' do
      let(:google_data) { { uid: google_uid, email: '  Google-User@Example.COM  ', name: '山田 太郎' } }
      let!(:existing_user) { create(:user, provider: 'email', uid: email, email:, user_id: 'yamada') }

      it '正規化して既存ユーザーにリンクする' do
        expect do
          post '/api/v1/google_sign_in', params: { id_token: 'valid_token' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)
        expect(existing_user.reload.provider).to eq('google')
      end
    end
  end
end
