require 'rails_helper'

RSpec.describe ManagementNotice, type: :model do
  describe 'バリデーション' do
    it 'title, body, status が必須である' do
      notice = described_class.new
      notice.valid?
      expect(notice.errors[:title]).to include('を入力してください')
      expect(notice.errors[:body]).to include('を入力してください')
    end

    it 'title は200文字以内' do
      notice = build(:management_notice, title: 'a' * 201)
      expect(notice).not_to be_valid
    end
  end

  describe '#set_published_at' do
    it 'draft から published に変更すると published_at がセットされる' do
      notice = create(:management_notice, status: :draft)
      expect { notice.update!(status: :published) }.to change { notice.reload.published_at }.from(nil)
    end
  end

  describe '#enqueue_push_notification_if_needed' do
    context '新規作成で status: published の場合' do
      it 'ManagementNoticePushJob がenqueueされる' do
        expect do
          create(:management_notice, :published)
        end.to have_enqueued_job(ManagementNoticePushJob)
      end
    end

    context '新規作成で status: draft の場合' do
      it 'ManagementNoticePushJob はenqueueされない' do
        expect do
          create(:management_notice, status: :draft)
        end.not_to have_enqueued_job(ManagementNoticePushJob)
      end
    end

    context 'draft → published の更新の場合' do
      it 'ManagementNoticePushJob がenqueueされる' do
        notice = create(:management_notice, status: :draft)
        expect do
          notice.update!(status: :published)
        end.to have_enqueued_job(ManagementNoticePushJob).with(notice.id)
      end
    end

    context 'published 状態でタイトルのみを更新した場合' do
      it 'ManagementNoticePushJob はenqueueされない（status変更がないため）' do
        notice = create(:management_notice, :published, notified_at: Time.current)
        expect do
          notice.update!(title: 'タイトル変更')
        end.not_to have_enqueued_job(ManagementNoticePushJob)
      end
    end

    context 'notified_at が既にセットされた状態で draft → published に変更した場合' do
      it 'ManagementNoticePushJob はenqueueされない（重複防止）' do
        notice = create(:management_notice, status: :draft, notified_at: Time.current)
        expect do
          notice.update!(status: :published)
        end.not_to have_enqueued_job(ManagementNoticePushJob)
      end
    end
  end
end
