require 'rails_helper'

RSpec.describe 'Api::V1::Notifications - ManagementNotice', type: :request do
  # ManagementNotice#set_published_at が新規作成時に published_at を Time.current で
  # 上書きするため、任意の published_at を検証したい場合は保存後に update_column で
  # コールバックを回避して固定する。
  def published_notice(published_at:)
    notice = create(:management_notice, :published)
    notice.update_column(:published_at, published_at) # rubocop:disable Rails/SkipsModelValidations
    notice
  end

  describe 'GET /api/v1/notifications' do
    it 'marks a notice published before signup as already read for a newly registered user' do
      old_notice = published_notice(published_at: 3.days.ago)
      new_user = create(:user, user_id: 'newcomer')

      get '/api/v1/notifications',
          params: { user_id: new_user.user_id },
          headers: auth_headers_for(new_user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      entry = json.find { |n| n['management_notice_id'] == old_notice.id }
      expect(entry['read_at']).to be_present
    end

    it 'still shows an unread notice published after signup' do
      new_user = create(:user, user_id: 'newcomer2')
      new_notice = published_notice(published_at: 1.minute.from_now)

      get '/api/v1/notifications',
          params: { user_id: new_user.user_id },
          headers: auth_headers_for(new_user)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      entry = json.find { |n| n['management_notice_id'] == new_notice.id }
      expect(entry['read_at']).to be_nil
    end
  end

  describe 'GET /api/v1/notifications/count' do
    it 'does not count a notice published before signup for a newly registered user' do
      published_notice(published_at: 3.days.ago)
      new_user = create(:user, user_id: 'newcomer3')

      get '/api/v1/notifications/count', headers: auth_headers_for(new_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['count']).to eq(0)
    end

    it 'counts a notice published after signup' do
      new_user = create(:user, user_id: 'newcomer4')
      published_notice(published_at: 1.minute.from_now)

      get '/api/v1/notifications/count', headers: auth_headers_for(new_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['count']).to eq(1)
    end
  end
end
