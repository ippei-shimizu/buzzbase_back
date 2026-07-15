require 'rails_helper'

RSpec.describe 'Api::V2::Schedules::WeekCopies', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'POST /api/v2/schedules/week_copy' do
    context '未認証' do
      it '401' do
        post '/api/v2/schedules/week_copy', params: { week_start: '2026-07-06' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '無料ユーザーは403（Pro限定機能）' do
      create(:schedule, user:, title: '朝練', days_of_week: nil, planned_on: '2026-07-06', scheduled_time: '06:00')
      post '/api/v2/schedules/week_copy', params: { week_start: '2026-07-06' }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Proユーザーは週内の単発予定を翌週へ複製する' do
      make_pro(user)
      menu = create(:practice_menu, user:)
      schedule = create(:schedule, user:, title: '朝練', days_of_week: nil,
                                   planned_on: '2026-07-06', scheduled_time: '06:00')
      schedule.schedule_menus.create!(practice_menu: menu, target_value: 100, sort_order: 0)
      # 繰り返し予定は対象外。
      create(:schedule, user:, title: '毎週の素振り', days_of_week: '1', scheduled_time: '06:00')

      expect do
        post '/api/v2/schedules/week_copy', params: { week_start: '2026-07-06' }, headers: auth_headers_for(user)
      end.to change { user.schedules.count }.by(1)

      expect(response).to have_http_status(:created)
      copied = response.parsed_body.first
      expect(copied['planned_on']).to eq('2026-07-13')
      expect(copied['title']).to eq('朝練')
      expect(copied['menus'].first['practice_menu_id']).to eq(menu.id)
    end

    it 'コピー元の週に単発予定が無ければ空配列を返す' do
      make_pro(user)
      post '/api/v2/schedules/week_copy', params: { week_start: '2026-07-06' }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq([])
    end

    it 'week_start が不正なら422' do
      make_pro(user)
      post '/api/v2/schedules/week_copy', params: { week_start: 'invalid' }, headers: auth_headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
