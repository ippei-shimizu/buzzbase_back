require 'rails_helper'

RSpec.describe 'Api::V2::PracticeSessions', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }
  let!(:batting_menu) { create(:practice_menu, user:, name: '素振り', unit_label: '本') }
  let!(:defense_menu) { create(:practice_menu, user:, name: 'ノック', unit_label: '本', category: 'defense') }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'POST /api/v2/practice_sessions' do
    let(:items) do
      [
        { practice_menu_id: batting_menu.id, amount: 200, memo: '外角重点' },
        { practice_menu_id: defense_menu.id, amount: 50 }
      ]
    end

    context '未認証' do
      it '401' do
        post '/api/v2/practice_sessions', params: { practice_session: { logged_on: today, items: } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '日付＋複数メニューを1リクエストで束ねて保存する' do
      post '/api/v2/practice_sessions', params: { practice_session: { logged_on: today, memo: '今日の振り返り', items: } },
                                        headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['memo']).to eq('今日の振り返り')
      expect(body['practice_logs'].size).to eq(2)
      expect(body['practice_logs'].pluck('menu_name')).to contain_exactly('素振り', 'ノック')
    end

    it '同日への再 POST は同一セッションを upsert し項目を差分同期する' do
      post '/api/v2/practice_sessions', params: { practice_session: { logged_on: today, items: } },
                                        headers: auth_headers_for(user)
      expect do
        post '/api/v2/practice_sessions',
             params: { practice_session: { logged_on: today, items: [{ practice_menu_id: batting_menu.id, amount: 300 }] } },
             headers: auth_headers_for(user)
      end.not_to(change { user.practice_sessions.count })

      session = user.practice_sessions.find_by(logged_on: today)
      expect(session.practice_logs.where(source: 'manual').count).to eq(1)
      expect(session.practice_logs.find_by(practice_menu: batting_menu).amount.to_i).to eq(300)
    end

    it '筋トレ（weight_reps）は重さと回数を保存する' do
      strength_menu = create(:practice_menu, user:, name: 'ベンチプレス', category: 'strength',
                                             unit: 'weight_reps', unit_label: '回')
      post '/api/v2/practice_sessions',
           params: { practice_session: { logged_on: today,
                                         items: [{ practice_menu_id: strength_menu.id, weight: 60, amount: 10 }] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      log = response.parsed_body['practice_logs'].first
      expect(log['weight'].to_f).to eq(60.0)
      expect(log['amount'].to_f).to eq(10.0)
    end

    it '保存で当日の activity_log が再計算される' do
      expect do
        post '/api/v2/practice_sessions', params: { practice_session: { logged_on: today, items: } },
                                          headers: auth_headers_for(user)
      end.to change { user.activity_logs.where(activity_date: today).count }.from(0).to(1)
    end

    context 'コンディション付き' do
      let(:condition) { { fatigue_level: 3, physical_level: 4, sleep_hours: 7.5, mood: '好調' } }

      it '無料ユーザーは 403（コンディションは Pro 限定）' do
        post '/api/v2/practice_sessions', params: { practice_session: { logged_on: today, items:, condition: } },
                                          headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'Pro ユーザーはセッションと同時にコンディションを保存できる' do
        make_pro(user)
        post '/api/v2/practice_sessions', params: { practice_session: { logged_on: today, items:, condition: } },
                                          headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['condition']['mood']).to eq('好調')
        expect(user.condition_logs.find_by(logged_on: today)).to be_present
      end
    end
  end

  describe 'GET /api/v2/practice_sessions/:id' do
    it '自分のセッションを項目付きで返す' do
      session = create(:practice_session, user:, logged_on: today)
      create(:practice_log, user:, practice_session: session, practice_menu: batting_menu, logged_on: today)
      get "/api/v2/practice_sessions/#{session.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(session.id)
      expect(response.parsed_body['practice_logs'].size).to eq(1)
    end

    it '他ユーザーのセッションは 404' do
      other = create(:practice_session, user: create(:user))
      get "/api/v2/practice_sessions/#{other.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v2/practice_sessions/by_date' do
    it '指定日のセッションを項目付きで返す' do
      post '/api/v2/practice_sessions',
           params: { practice_session: { logged_on: today, items: [{ practice_menu_id: batting_menu.id, amount: 100 }] } },
           headers: auth_headers_for(user)

      get '/api/v2/practice_sessions/by_date', params: { date: today.to_s }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['practice_logs'].size).to eq(1)
    end

    it 'セッションが無い日は null を返す' do
      get '/api/v2/practice_sessions/by_date', params: { date: today.to_s }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('null')
    end
  end

  describe 'GET /api/v2/practice_sessions' do
    let!(:session_today) { create(:practice_session, user:, logged_on: today) }
    let!(:session_old) { create(:practice_session, user:, logged_on: today - 40) }

    it 'from で期間絞り込みでき新しい順で返す' do
      get '/api/v2/practice_sessions', params: { from: (today - 7).to_s }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.pluck('id')
      expect(ids).to include(session_today.id)
      expect(ids).not_to include(session_old.id)
    end
  end

  describe 'DELETE /api/v2/practice_sessions/:id' do
    let!(:session) { create(:practice_session, user:, logged_on: today) }

    it '削除できる' do
      delete "/api/v2/practice_sessions/#{session.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(user.practice_sessions.exists?(session.id)).to be false
    end
  end
end
