require 'rails_helper'

RSpec.describe 'Api::V2::ShadowSwingSessions', type: :request do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  describe 'POST /api/v2/shadow_swing_sessions' do
    context '未認証' do
      it '401' do
        post '/api/v2/shadow_swing_sessions',
             params: { shadow_swing_session: { target_count: 200 } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'セッションを作成する（無料で利用可）' do
      post '/api/v2/shadow_swing_sessions',
           params: { shadow_swing_session: { target_count: 200 } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['target_count']).to eq(200)
    end

    # クライアントのロック表示は直接 API を叩けば回避できるため、サーバー側で弾く。
    context 'Pro 限定の設定を無料ユーザーが指定したとき' do
      it '無料枠外のインターバルを 422 で拒否する' do
        post '/api/v2/shadow_swing_sessions',
             params: { shadow_swing_session: { target_count: 200, interval_seconds: 1.0 } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(user.shadow_swing_sessions).to be_empty
      end

      it 'バイブレーションの有効化を 422 で拒否する' do
        post '/api/v2/shadow_swing_sessions',
             params: { shadow_swing_session: { target_count: 200, interval_seconds: 5.0, vibration_enabled: true } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it '無料枠内のインターバルは受け付ける' do
        post '/api/v2/shadow_swing_sessions',
             params: { shadow_swing_session: { target_count: 200, interval_seconds: 10.0 } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['interval_seconds']).to eq(10.0)
      end
    end

    context 'Pro ユーザーのとき' do
      before { user.subscription.update!(status: 'active', expires_at: 30.days.from_now) }

      it '全範囲のインターバルとバイブレーションを保存して返す' do
        post '/api/v2/shadow_swing_sessions',
             params: { shadow_swing_session: { target_count: 200, interval_seconds: 1.0, vibration_enabled: true } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include('interval_seconds' => 1.0, 'vibration_enabled' => true)
      end
    end
  end

  describe 'POST /api/v2/shadow_swing_sessions/:id/complete' do
    let!(:session) { create(:shadow_swing_session, user:, target_count: 200) }

    it '完了時に素振りの練習ログを自動生成する' do
      expect do
        post "/api/v2/shadow_swing_sessions/#{session.id}/complete",
             params: { shadow_swing_session: { swing_count: 200 } },
             headers: auth_headers_for(user)
      end.to change { user.practice_logs.where(source: 'shadow_swing').count }.from(0).to(1)

      expect(response).to have_http_status(:ok)
      log = user.practice_logs.find_by(source: 'shadow_swing')
      expect(log.menu_name).to eq('素振り')
      expect(log.amount.to_i).to eq(200)
      expect(session.reload.practice_log_id).to eq(log.id)
    end

    it '完了で当日の activity_logs が再計算され、本数が強度に反映される' do
      post "/api/v2/shadow_swing_sessions/#{session.id}/complete",
           params: { shadow_swing_session: { swing_count: 300 } },
           headers: auth_headers_for(user)

      activity_log = user.activity_logs.find_by(activity_date: today)
      expect(activity_log.total_swing_count).to eq(300)
      expect(activity_log.intensity_level).to eq(3)
    end

    it '素振り本数を二重計上しない（ShadowSwingSession と練習ログで重複しない）' do
      post "/api/v2/shadow_swing_sessions/#{session.id}/complete",
           params: { shadow_swing_session: { swing_count: 150 } },
           headers: auth_headers_for(user)

      expect(user.activity_logs.find_by(activity_date: today).total_swing_count).to eq(150)
    end

    # 開始してすぐ「終了」を押すだけで草・Streak を水増しできてしまうのを防ぐ。
    context '0本で完了したとき' do
      it '練習ログを作らず、当日を活動ありにしない' do
        expect do
          post "/api/v2/shadow_swing_sessions/#{session.id}/complete",
               params: { shadow_swing_session: { swing_count: 0 } },
               headers: auth_headers_for(user)
        end.not_to(change { user.practice_logs.count })

        expect(response).to have_http_status(:ok)
        expect(user.activity_logs.find_by(activity_date: today)).to be_nil
      end

      it 'セッション自体は完了扱いにする（開始したまま残さない）' do
        post "/api/v2/shadow_swing_sessions/#{session.id}/complete",
             params: { shadow_swing_session: { swing_count: 0 } },
             headers: auth_headers_for(user)

        expect(session.reload).to have_attributes(swing_count: 0, practice_log_id: nil)
        expect(session.completed_at).to be_present
      end
    end
  end

  describe 'GET /api/v2/shadow_swing_sessions/stats' do
    before do
      create(:practice_log, :shadow_swing, user:, logged_on: today, amount: 100)
      create(:practice_log, :shadow_swing, user:, logged_on: today - 40, amount: 50)
    end

    it '今日・今月・通算の本数を返す' do
      get '/api/v2/shadow_swing_sessions/stats', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['today_count']).to eq(100)
      expect(body['total_count']).to eq(150)
    end
  end

  describe 'GET /api/v2/shadow_swing_sessions/trend' do
    def make_pro(target)
      target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
    end

    it '無料ユーザーは403（推移詳細は Pro 限定）' do
      get '/api/v2/shadow_swing_sessions/trend', headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Proユーザーは素振りの年別・月別・日別の集計を返す' do
      make_pro(user)
      create(:practice_log, :shadow_swing, user:, logged_on: today, amount: 100)
      create(:practice_log, :shadow_swing, user:, logged_on: today - 40, amount: 50)

      get '/api/v2/shadow_swing_sessions/trend', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['menu']['name']).to eq('素振り')
      expect(body['menu']['is_weight_reps']).to be(false)
      expect(body['by_year'].first['period']).to eq(today.year.to_s)
      expect(body['by_month'].first['total_amount'].to_f).to eq(100)
    end
  end
end
