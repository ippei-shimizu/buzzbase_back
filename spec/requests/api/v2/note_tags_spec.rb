require 'rails_helper'

RSpec.describe 'Api::V2::NoteTags', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/note_tags' do
    before do
      create(:note_tag, :preset, name: '打撃')
      create(:note_tag, user:, name: '自主練')
      create(:note_tag, user: create(:user), name: '他人')
    end

    it '未認証は401' do
      get '/api/v2/note_tags'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'プリセットと自作を返し他人分は含めない' do
      get '/api/v2/note_tags', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      names = response.parsed_body.pluck('name')
      expect(names).to include('打撃', '自主練')
      expect(names).not_to include('他人')
    end
  end

  describe 'POST /api/v2/note_tags' do
    it '自作タグを作成する' do
      post '/api/v2/note_tags', params: { note_tag: { name: 'メンタル' } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('メンタル')
    end

    it '同名は422' do
      create(:note_tag, user:, name: 'メンタル')
      post '/api/v2/note_tags', params: { note_tag: { name: 'メンタル' } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
