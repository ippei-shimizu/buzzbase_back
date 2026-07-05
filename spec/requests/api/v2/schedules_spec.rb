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

    context '無料ユーザーが上限(3)を超える' do
      before { create_list(:schedule, 3, user:) }

      it '403' do
        post '/api/v2/schedules', params:, headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
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
    end
  end

  describe 'DELETE /api/v2/schedules/:id' do
    let!(:schedule) { create(:schedule, user:) }

    it '削除する' do
      delete "/api/v2/schedules/#{schedule.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(Schedule.exists?(schedule.id)).to be(false)
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
