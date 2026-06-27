require 'rails_helper'

RSpec.describe 'Api::V2::PracticeLogs', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }
  let!(:menu) { create(:practice_menu, user:, name: '素振り', unit_label: '本') }

  describe 'POST /api/v2/practice_logs' do
    let(:params) { { practice_log: { practice_menu_id: menu.id, logged_on: today, amount: 200, memo: '外角重点' } } }

    context '未認証' do
      it '401' do
        post '/api/v2/practice_logs', params: { practice_log: { practice_menu_id: menu.id, logged_on: today, amount: 1 } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'メニュー名・単位ラベルをスナップショットして作成する' do
      post '/api/v2/practice_logs', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['menu_name']).to eq('素振り')
      expect(body['unit_label']).to eq('本')
      expect(body['amount'].to_f).to eq(200.0)
    end

    it '作成で当日の activity_log が再計算される' do
      expect do
        post '/api/v2/practice_logs', params:, headers: auth_headers_for(user)
      end.to change { user.activity_logs.where(activity_date: today).count }.from(0).to(1)
    end
  end

  describe 'GET /api/v2/practice_logs' do
    let!(:log_today) { create(:practice_log, user:, practice_menu: menu, logged_on: today) }
    let!(:log_old) { create(:practice_log, user:, practice_menu: menu, logged_on: today - 40) }

    it 'from で期間絞り込みできる（無料でも全期間取得可）' do
      get '/api/v2/practice_logs', params: { from: (today - 7).to_s }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.pluck('id')
      expect(ids).to include(log_today.id)
      expect(ids).not_to include(log_old.id)
    end
  end

  describe 'DELETE /api/v2/practice_logs/:id' do
    let!(:log) { create(:practice_log, user:, practice_menu: menu, logged_on: today) }

    it '削除できる' do
      delete "/api/v2/practice_logs/#{log.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(PracticeLog.exists?(log.id)).to be(false)
    end
  end
end
