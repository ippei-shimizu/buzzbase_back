require 'rails_helper'

RSpec.describe 'Api::V1::Seasons', type: :request do
  let(:user) { create(:user) }

  describe 'POST /api/v1/seasons' do
    context '未認証' do
      it '401' do
        post '/api/v1/seasons', params: { season: { name: '2026春' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '新規シーズンを作成して201を返す' do
      expect do
        post '/api/v1/seasons', params: { season: { name: '2026春' } }, headers: auth_headers_for(user)
      end.to change(Season, :count).by(1)

      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['name']).to eq('2026春')
      end
    end

    it '同名シーズンが既にある場合は新規作成せず既存のidを返す' do
      existing = create(:season, user:, name: '2026春')

      expect do
        post '/api/v1/seasons', params: { season: { name: '2026春' } }, headers: auth_headers_for(user)
      end.not_to change(Season, :count)

      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['id']).to eq(existing.id)
      end
    end

    it '前後の空白違いでも既存のidを返す' do
      existing = create(:season, user:, name: '2026春')

      post '/api/v1/seasons', params: { season: { name: '  2026春　' } }, headers: auth_headers_for(user)

      expect(response.parsed_body['id']).to eq(existing.id)
    end

    it '他ユーザーが同名を持っていても自分のシーズンが作られる' do
      create(:season, user: create(:user), name: '2026春')

      post '/api/v1/seasons', params: { season: { name: '2026春' } }, headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:created)
        expect(user.seasons.pluck(:name)).to eq(['2026春'])
      end
    end

    it 'name が空なら422と日本語のエラーメッセージを返す' do
      post '/api/v1/seasons', params: { season: { name: '' } }, headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('シーズン名 を入力してください')
      end
    end

    it 'name が上限超過なら422と日本語のエラーメッセージを返す' do
      post '/api/v1/seasons', params: { season: { name: 'a' * 51 } }, headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('シーズン名 は50文字以内で入力してください')
      end
    end
  end

  describe 'DELETE /api/v1/seasons/:id' do
    let!(:season) { create(:season, user:) }

    context '未認証' do
      it '401' do
        delete "/api/v1/seasons/#{season.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '紐づく進行中のシーズン目標が無ければ削除できる' do
      delete "/api/v1/seasons/#{season.id}", headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('シーズンを削除しました')
        expect(Season.exists?(season.id)).to be false
      end
    end

    it '進行中のシーズン目標が紐づいている場合は422とエラーメッセージを返す' do
      create(:goal, user:, season:, period_type: 'season', month_start: nil, is_finalized: false)

      delete "/api/v1/seasons/#{season.id}", headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('進行中のシーズン目標が紐づいているため削除できません')
        expect(Season.exists?(season.id)).to be true
      end
    end
  end
end
