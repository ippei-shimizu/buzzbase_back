require 'rails_helper'

RSpec.describe 'Api::V2::Stadiums', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/stadiums' do
    let!(:tokyo) { Prefecture.create!(name: 'スタジアム検証_東京') }
    let!(:osaka) { Prefecture.create!(name: 'スタジアム検証_大阪') }

    before do
      Stadium.create!(name: 'テスト東京ドーム', prefecture: tokyo, created_by_user: user)
      Stadium.create!(name: 'テスト京セラドーム', prefecture: osaka, created_by_user: user)
    end

    context 'when authenticated' do
      it 'returns 200 with paginated stadiums' do
        get '/api/v2/stadiums', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('data')
        expect(json).to have_key('pagination')
      end

      it 'q パラメータで部分一致検索ができる' do
        get '/api/v2/stadiums', params: { q: '京セラ' }, headers: auth_headers_for(user)
        names = response.parsed_body['data'].pluck('name')
        expect(names).to include('テスト京セラドーム')
        expect(names).not_to include('テスト東京ドーム')
      end

      it 'prefecture_id で都道府県絞り込みができる' do
        get '/api/v2/stadiums', params: { prefecture_id: tokyo.id }, headers: auth_headers_for(user)
        names = response.parsed_body['data'].pluck('name')
        expect(names).to include('テスト東京ドーム')
        expect(names).not_to include('テスト京セラドーム')
      end

      it 'per_page は MAX_PER_PAGE (100) を超えられない（DoS防止）' do
        get '/api/v2/stadiums', params: { per_page: 999_999 }, headers: auth_headers_for(user)
        expect(response.parsed_body['pagination']['per_page']).to eq(100)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/stadiums'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v2/stadiums' do
    let!(:prefecture) { Prefecture.create!(name: 'スタジアム検証_愛知') }

    context 'when authenticated' do
      it '新規球場を作成して created_by_user_id を自動付与する' do
        post '/api/v2/stadiums',
             params: { stadium: { name: 'テストナゴヤドーム', prefecture_id: prefecture.id } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        created = Stadium.find_by(name: 'テストナゴヤドーム')
        expect(created).to be_present
        expect(created.created_by_user_id).to eq(user.id)
        expect(created.prefecture_id).to eq(prefecture.id)
      end

      it 'name が空の場合は 422' do
        post '/api/v2/stadiums',
             params: { stadium: { name: '', prefecture_id: prefecture.id } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to be_present
      end

      it '同一県内で同名の場合は 422（一意性違反）' do
        Stadium.create!(name: '重複テスト球場', prefecture:, created_by_user: user)
        post '/api/v2/stadiums',
             params: { stadium: { name: '重複テスト球場', prefecture_id: prefecture.id } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v2/stadiums', params: { stadium: { name: 'X' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
