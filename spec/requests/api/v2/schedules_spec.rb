require 'rails_helper'

RSpec.describe 'Api::V2::Schedules', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/schedules' do
    context '未認証' do
      it '401' do
        get '/api/v2/schedules'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'active なスケジュールを返す' do
      create(:schedule, user:, title: '朝練')
      create(:schedule, user:, title: '休止中', active: false)
      get '/api/v2/schedules', headers: auth_headers_for(user)
      titles = response.parsed_body.pluck('title')
      expect(titles).to include('朝練')
      expect(titles).not_to include('休止中')
    end
  end

  describe 'POST /api/v2/schedules' do
    let(:menu) { create(:practice_menu, user:) }
    let(:params) do
      {
        schedule: {
          title: '朝の素振り', days_of_week: '1,3,5', scheduled_time: '06:00',
          menus: [{ practice_menu_id: menu.id, target_value: 200 }]
        }
      }
    end

    it 'メニュー紐付きで作成する' do
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['title']).to eq('朝の素振り')
      expect(body['menus'].first['practice_menu_id']).to eq(menu.id)
    end

    it '他ユーザーのメニューは紐付けられない（IDOR防止）' do
      other_menu = create(:practice_menu, user: create(:user))
      post '/api/v2/schedules',
           params: { schedule: { title: 'x', days_of_week: '1', scheduled_time: '06:00',
                                 menus: [{ practice_menu_id: other_menu.id, target_value: 1 }] } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['menus']).to be_empty
    end

    it '無料ユーザーでも件数上限なく作成できる' do
      create_list(:schedule, 3, user:)
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
    end

    context '終了時刻・メモ' do
      it '終了時刻とメモを保存し "HH:MM" 形式で返す' do
        post '/api/v2/schedules',
             params: { schedule: { title: '全体練習', days_of_week: '1', scheduled_time: '09:00',
                                   end_time: '12:30', note: '集合はグラウンド前' } },
             headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body['end_time']).to eq('12:30')
        expect(body['note']).to eq('集合はグラウンド前')
      end

      it '終了時刻のみの指定は422' do
        post '/api/v2/schedules',
             params: { schedule: { title: 'x', days_of_week: '1', end_time: '12:30' } },
             headers: auth_headers_for(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'メモが長すぎると読めるエラーを返す' do
        post '/api/v2/schedules',
             params: { schedule: { title: 'x', days_of_week: '1', note: 'あ' * 2001 } },
             headers: auth_headers_for(user)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('メモは2000文字以内で入力してください')
      end

      it '終了時刻が開始時刻以前だと422' do
        post '/api/v2/schedules',
             params: { schedule: { title: 'x', days_of_week: '1', scheduled_time: '09:00', end_time: '09:00' } },
             headers: auth_headers_for(user)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('終了時刻は開始時刻より後にしてください')
      end

      it '終了時刻なしでも作成できる' do
        post '/api/v2/schedules',
             params: { schedule: { title: 'x', days_of_week: '1', scheduled_time: '09:00' } },
             headers: auth_headers_for(user)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['end_time']).to be_nil
      end
    end

    context 'カスタム通知文' do
      let(:custom_params) do
        { schedule: { title: 'x', days_of_week: '1', scheduled_time: '06:00', notification_message: '頑張れ' } }
      end

      it '無料ユーザーは無視される' do
        post '/api/v2/schedules', params: custom_params, headers: auth_headers_for(user)
        expect(response.parsed_body['notification_message']).to be_nil
      end

      it 'Pro ユーザーは保存される' do
        make_pro(user)
        post '/api/v2/schedules', params: custom_params, headers: auth_headers_for(user)
        expect(response.parsed_body['notification_message']).to eq('頑張れ')
      end

      # 解約しても DB には過去に設定した通知文が残るため、参照時点の entitlement で出し分ける。
      it 'Pro 期間中に設定した通知文は、解約後は返さない' do
        make_pro(user)
        post '/api/v2/schedules', params: custom_params, headers: auth_headers_for(user)
        user.subscription.update!(status: 'expired', expires_at: 1.day.ago)

        get '/api/v2/schedules', headers: auth_headers_for(user)
        expect(response.parsed_body.first['notification_message']).to be_nil
      end
    end
  end

  describe 'PATCH /api/v2/schedules/:id' do
    let(:menu) { create(:practice_menu, user:) }
    let!(:schedule) do
      create(:schedule, user:, title: '朝練', days_of_week: '1', scheduled_time: '06:00')
    end

    before do
      patch "/api/v2/schedules/#{schedule.id}",
            params: { schedule: { menus: [{ practice_menu_id: menu.id, target_value: 100 }] } },
            headers: auth_headers_for(user)
    end

    it 'メニューを更新できる' do
      patch "/api/v2/schedules/#{schedule.id}",
            params: { schedule: { title: '朝練2' } }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['title']).to eq('朝練2')
    end

    it 'バリデーション失敗時は schedule_menus を巻き戻し、保存前の状態を維持する（トランザクションバグの回帰防止）' do
      expect(schedule.reload.schedule_menus.count).to eq(1)

      # menus を含めて assign_menus（destroy_all → 再build）を発火させつつ、
      # title/days_of_week/planned_on を不正にして save! を失敗させる。
      patch "/api/v2/schedules/#{schedule.id}",
            params: { schedule: { title: '', days_of_week: '', planned_on: '',
                                  menus: [{ practice_menu_id: menu.id, target_value: 999 }] } },
            headers: auth_headers_for(user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(schedule.reload.schedule_menus.count).to eq(1)
      expect(schedule.schedule_menus.first.target_value.to_i).to eq(100)
    end
  end

  describe 'GET /api/v2/schedules（logged_practice_menu_ids）' do
    it '練習ログが記録済みのpractice_menu_idを返す' do
      schedule = create(:schedule, user:, title: '朝練', days_of_week: '1', scheduled_time: '06:00')
      menu = create(:practice_menu, user:)
      create(:practice_log, user:, practice_menu: menu, schedule:, logged_on: '2026-07-09')

      get '/api/v2/schedules', headers: auth_headers_for(user)

      body = response.parsed_body.find { |item| item['id'] == schedule.id }
      expect(body['logged_practice_menu_ids']).to eq([menu.id])
    end
  end

  describe 'DELETE /api/v2/schedules/:id' do
    let!(:schedule) { create(:schedule, user:) }

    it '削除する' do
      delete "/api/v2/schedules/#{schedule.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(Schedule.exists?(schedule.id)).to be(false)
    end

    it '紐づく練習ログがあっても削除でき、ログは schedule_id が外れて残る' do
      menu = create(:practice_menu, user:)
      log = create(:practice_log, user:, practice_menu: menu, schedule:, logged_on: '2026-07-09')

      delete "/api/v2/schedules/#{schedule.id}", headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(Schedule.exists?(schedule.id)).to be(false)
      expect(log.reload.schedule_id).to be_nil
    end
  end

  describe '単発（planned_on）・event_type の割り当て' do
    it '日付指定の単発予定を作成する' do
      params = { schedule: { title: '試合 vs 港南中', planned_on: '2026-07-11', scheduled_time: '09:00', event_type: 'game' } }
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['planned_on']).to eq('2026-07-11')
      expect(body['event_type']).to eq('game')
      expect(body['recurring']).to be(false)
    end

    it '曜日と日付を同時指定すると422' do
      params = { schedule: { title: 'x', days_of_week: '1', planned_on: '2026-07-11', scheduled_time: '09:00' } }
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '曜日も日付も無いと422' do
      params = { schedule: { title: 'x', scheduled_time: '09:00' } }
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'メニューセットを紐付けるとタイトル未指定でもセット名を返す' do
      menu_set = create(:menu_set, user:, name: 'オフ日ルーティン')
      params = { schedule: { menu_set_id: menu_set.id, days_of_week: '1', scheduled_time: '06:00' } }
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['title']).to eq('オフ日ルーティン')
    end

    it '他ユーザーのメニューセットは紐付けられない（IDOR防止）' do
      other_set = create(:menu_set, user: create(:user))
      params = { schedule: { title: 'x', menu_set_id: other_set.id, days_of_week: '1', scheduled_time: '06:00' } }
      post '/api/v2/schedules', params:, headers: auth_headers_for(user)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['menu_set_id']).to be_nil
    end
  end
end
