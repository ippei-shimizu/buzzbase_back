require 'rails_helper'

RSpec.describe PurgeStaleMediaAttachmentsJob do
  let(:user) { create(:user) }
  let(:note) { create(:baseball_note, user:) }

  describe '#perform' do
    it '猶予を過ぎた pending / failed を削除し、R2 オブジェクトの削除も予約する' do
      stale_pending = create(:media_attachment, user:, baseball_note: note, created_at: 25.hours.ago)
      stale_failed = create(:media_attachment, user:, baseball_note: note, status: 'failed', created_at: 25.hours.ago)

      expect { described_class.perform_now }.to change(MediaAttachment, :count).by(-2)
      expect(MediaAttachment.where(id: [stale_pending.id, stale_failed.id])).to be_empty
      expect(MediaAttachmentDeletionJob).to have_been_enqueued.twice
    end

    it 'アップロード中かもしれない直近の pending は残す' do
      recent = create(:media_attachment, user:, baseball_note: note, created_at: 10.minutes.ago)

      expect { described_class.perform_now }.not_to change(MediaAttachment, :count)
      expect(recent.reload).to be_persisted
    end

    it '完了済み（ready）は古くても消さない' do
      create(:media_attachment, :ready, user:, baseball_note: note, created_at: 1.year.ago)

      expect { described_class.perform_now }.not_to change(MediaAttachment, :count)
    end
  end
end
