require 'rails_helper'

RSpec.describe 'Api::V1::BaseballNotes', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/baseball_notes' do
    context 'when authenticated' do
      # 試合日付と作成日時の前後関係を意図的にずらす
      let!(:old_created_recent_game) do
        create(:baseball_note, user:, date: Date.new(2026, 5, 1),
                               created_at: 3.days.ago, updated_at: 3.days.ago)
      end
      let!(:middle) do
        create(:baseball_note, user:, date: Date.new(2026, 3, 15),
                               created_at: 1.day.ago, updated_at: 1.day.ago)
      end
      let!(:new_created_old_game) do
        create(:baseball_note, user:, date: Date.new(2025, 1, 1),
                               created_at: 1.minute.ago, updated_at: 1.minute.ago)
      end

      it 'ノートを作成日時の降順で返す' do
        get '/api/v1/baseball_notes', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body.pluck('id')
        expect(ids).to eq([new_created_old_game.id, middle.id, old_created_recent_game.id])
      end
    end

    context 'when authenticated with multiple users' do
      it '他ユーザーのノートは含めない' do
        own = create(:baseball_note, user:)
        create(:baseball_note, user: create(:user))

        get '/api/v1/baseball_notes', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body.pluck('id')
        expect(ids).to eq([own.id])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/baseball_notes'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
