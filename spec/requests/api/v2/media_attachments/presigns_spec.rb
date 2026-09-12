require 'rails_helper'

RSpec.describe 'Api::V2::MediaAttachments::Presigns', type: :request do
  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 30.days.from_now)
  end

  let(:user) { create(:user) }
  let(:note) { create(:baseball_note, user:) }

  def presign(media_attachment:, headers: auth_headers_for(user))
    post '/api/v2/media_attachments/presign', params: { media_attachment: }, headers:
  end

  context 'when not authenticated' do
    it 'returns unauthorized' do
      presign(media_attachment: { baseball_note_id: note.id, media_type: 'image', content_type: 'image/jpeg' }, headers: {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when authenticated' do
    it 'creates a pending media_attachment and returns an upload_url for an image' do
      expect do
        presign(media_attachment: { baseball_note_id: note.id, media_type: 'image', content_type: 'image/jpeg' })
      end.to change(MediaAttachment, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['status']).to eq 'pending'
      expect(json['upload_url']).to be_present
      expect(json['thumbnail_upload_url']).to be_nil
    end

    it 'also returns a thumbnail_upload_url for a video' do
      presign(media_attachment: { baseball_note_id: note.id, media_type: 'video', content_type: 'video/mp4' })

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['thumbnail_upload_url']).to be_present
    end

    it 'returns not_found for another user note (IDOR)' do
      other_note = create(:baseball_note, user: create(:user))
      presign(media_attachment: { baseball_note_id: other_note.id, media_type: 'image', content_type: 'image/jpeg' })
      expect(response).to have_http_status(:not_found)
    end

    it 'returns unprocessable_entity for an unsupported content_type' do
      presign(media_attachment: { baseball_note_id: note.id, media_type: 'image', content_type: 'image/webp' })
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns unprocessable_entity when media_type and content_type do not match' do
      # media_type: 'image'で動画を送ると、complete_upload時にLimitValidatorが
      # valid_image?（file_size_bytesのみ）に流れ、動画の長さ・解像度チェックを回避できてしまう。
      presign(media_attachment: { baseball_note_id: note.id, media_type: 'image', content_type: 'video/mp4' })
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context 'monthly limit' do
      before do
        create_list(:media_attachment, 3, :ready, user:, baseball_note: note)
      end

      it 'returns forbidden for a free user who already used the monthly limit' do
        presign(media_attachment: { baseball_note_id: note.id, media_type: 'image', content_type: 'image/jpeg' })
        expect(response).to have_http_status(:forbidden)
      end

      it 'allows a Pro user beyond the monthly limit' do
        make_pro(user)
        presign(media_attachment: { baseball_note_id: note.id, media_type: 'image', content_type: 'image/jpeg' })
        expect(response).to have_http_status(:created)
      end
    end
  end
end
