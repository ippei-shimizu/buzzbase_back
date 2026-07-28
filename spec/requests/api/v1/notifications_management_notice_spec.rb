require 'rails_helper'

RSpec.describe 'Api::V1::Notifications - ManagementNotice', type: :request do
  describe 'GET /api/v1/notifications' do
    it 'marks a notice published before signup as already read for a newly registered user' do
      old_notice = create(:management_notice, :published, published_at: 3.days.ago)
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
      new_notice = create(:management_notice, :published, published_at: 1.minute.from_now)

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
      create(:management_notice, :published, published_at: 3.days.ago)
      new_user = create(:user, user_id: 'newcomer3')

      get '/api/v1/notifications/count', headers: auth_headers_for(new_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['count']).to eq(0)
    end

    it 'counts a notice published after signup' do
      new_user = create(:user, user_id: 'newcomer4')
      create(:management_notice, :published, published_at: 1.minute.from_now)

      get '/api/v1/notifications/count', headers: auth_headers_for(new_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['count']).to eq(1)
    end
  end
end
