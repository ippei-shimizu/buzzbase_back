require 'rails_helper'

RSpec.describe 'Api::V2::MediaAttachments', type: :request do
  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 30.days.from_now)
  end

  let(:user) { create(:user) }
  let(:note) { create(:baseball_note, user:) }

  describe 'PATCH /api/v2/media_attachments/:id' do
    let(:attachment) { create(:media_attachment, :video, user:, baseball_note: note) }

    def complete(attachment, params, headers: auth_headers_for(user))
      patch "/api/v2/media_attachments/#{attachment.id}", params: { media_attachment: params }, headers:
    end

    it 'marks the attachment as ready when within free limits' do
      complete(attachment, { duration_seconds: 25, width: 720, height: 480, file_size_bytes: 8_000_000 })

      expect(response).to have_http_status(:ok)
      expect(attachment.reload.status).to eq 'ready'
    end

    it 'returns not_found for another user attachment (IDOR)' do
      other_attachment = create(:media_attachment, :video, user: create(:user))
      complete(other_attachment, { duration_seconds: 10, width: 720, height: 480, file_size_bytes: 1_000 })
      expect(response).to have_http_status(:not_found)
    end

    it 'marks as failed and returns unprocessable_entity when a free user exceeds video duration' do
      complete(attachment, { duration_seconds: 31, width: 720, height: 480, file_size_bytes: 8_000_000 })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(attachment.reload.status).to eq 'failed'
    end

    it 'allows Pro users up to the pro video duration' do
      make_pro(user)
      complete(attachment, { duration_seconds: 180, width: 1080, height: 1080, file_size_bytes: 8_000_000 })

      expect(response).to have_http_status(:ok)
      expect(attachment.reload.status).to eq 'ready'
    end

    it 'returns unprocessable_entity when the attachment is already completed' do
      attachment.update!(status: 'ready')
      complete(attachment, { duration_seconds: 10, width: 720, height: 480, file_size_bytes: 1_000 })
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'accepts memo together with completion params' do
      complete(attachment, { duration_seconds: 25, width: 720, height: 480, file_size_bytes: 8_000_000, memo: '初回の所感' })

      expect(response).to have_http_status(:ok)
      expect(attachment.reload.memo).to eq '初回の所感'
    end
  end

  describe 'PATCH /api/v2/media_attachments/:id（メモ更新）' do
    let(:attachment) { create(:media_attachment, :ready, user:, baseball_note: note) }

    def update_memo(attachment, memo, headers: auth_headers_for(user))
      patch "/api/v2/media_attachments/#{attachment.id}", params: { media_attachment: { memo: } }, headers:
    end

    it 'updates the memo of an already-ready attachment' do
      long_text = "1段落目です。\n\n2段落目、フォームについての詳しい所感。" * 5
      update_memo(attachment, long_text)

      expect(response).to have_http_status(:ok)
      expect(attachment.reload.memo).to eq long_text
      expect(response.parsed_body['memo']).to eq long_text
    end

    it 'does not require re-validation of upload limits' do
      make_pro(user)
      update_memo(attachment, 'メモだけ更新')
      expect(response).to have_http_status(:ok)
    end

    it 'returns not_found for another user attachment (IDOR)' do
      other_attachment = create(:media_attachment, :ready, user: create(:user))
      update_memo(other_attachment, 'メモ')
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v2/media_attachments/:id' do
    let(:attachment) { create(:media_attachment, :ready, user:, baseball_note: note) }

    it 'destroys the attachment and enqueues R2 object deletion' do
      expect do
        delete "/api/v2/media_attachments/#{attachment.id}", headers: auth_headers_for(user)
      end.to have_enqueued_job(MediaAttachmentDeletionJob).with(attachment.r2_key, attachment.thumbnail_r2_key)

      expect(response).to have_http_status(:ok)
      expect(MediaAttachment.exists?(attachment.id)).to be false
    end

    it 'returns not_found for another user attachment (IDOR)' do
      other_attachment = create(:media_attachment, :ready, user: create(:user))
      delete "/api/v2/media_attachments/#{other_attachment.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
