require 'rails_helper'

RSpec.describe 'Api::V1::Admin::ManagementNotices', type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{InternalJwtService.encode_access_token(admin_user.id)}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'POST /api/v1/admin/management_notices' do
    context 'status: published で新規作成する場合' do
      let(:params) do
        {
          management_notice: {
            title: 'お知らせタイトル',
            body: '本文',
            status: 'published'
          }
        }
      end

      it 'ManagementNoticePushJob がenqueueされる' do
        expect do
          post '/api/v1/admin/management_notices', params: params.to_json, headers:
        end.to have_enqueued_job(ManagementNoticePushJob)

        expect(response).to have_http_status(:created)
      end
    end

    context 'status: draft で新規作成する場合' do
      let(:params) do
        {
          management_notice: {
            title: 'お知らせタイトル',
            body: '本文',
            status: 'draft'
          }
        }
      end

      it 'ManagementNoticePushJob はenqueueされない' do
        expect do
          post '/api/v1/admin/management_notices', params: params.to_json, headers:
        end.not_to have_enqueued_job(ManagementNoticePushJob)

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'PATCH /api/v1/admin/management_notices/:id' do
    context 'draft から published への更新の場合' do
      let!(:notice) { create(:management_notice, status: :draft, created_by: admin_user) }
      let(:params) { { management_notice: { status: 'published' } } }

      it 'ManagementNoticePushJob がenqueueされる' do
        expect do
          patch "/api/v1/admin/management_notices/#{notice.id}", params: params.to_json, headers:
        end.to have_enqueued_job(ManagementNoticePushJob).with(notice.id)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'published 状態でタイトルのみ変更する場合' do
      let!(:notice) { create(:management_notice, :published, notified_at: Time.current, created_by: admin_user) }
      let(:params) { { management_notice: { title: 'タイトル変更' } } }

      it 'ManagementNoticePushJob はenqueueされない' do
        expect do
          patch "/api/v1/admin/management_notices/#{notice.id}", params: params.to_json, headers:
        end.not_to have_enqueued_job(ManagementNoticePushJob)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
