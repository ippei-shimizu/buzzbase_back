require 'rails_helper'

RSpec.describe 'Api::V1::Seasons', type: :request do
  let(:user) { create(:user) }

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
