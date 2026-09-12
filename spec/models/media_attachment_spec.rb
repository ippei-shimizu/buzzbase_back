require 'rails_helper'

RSpec.describe MediaAttachment, type: :model do
  describe 'validations' do
    it 'requires a valid media_type' do
      attachment = build(:media_attachment, media_type: 'audio')
      expect(attachment).not_to be_valid
      expect(attachment.errors[:media_type]).to be_present
    end

    it 'requires a valid status' do
      attachment = build(:media_attachment, status: 'uploading')
      expect(attachment).not_to be_valid
      expect(attachment.errors[:status]).to be_present
    end

    it 'requires r2_key' do
      attachment = build(:media_attachment, r2_key: nil)
      expect(attachment).not_to be_valid
      expect(attachment.errors[:r2_key]).to be_present
    end
  end

  describe '#video?' do
    it 'returns true for video attachments' do
      expect(build(:media_attachment, :video).video?).to be true
    end

    it 'returns false for image attachments' do
      expect(build(:media_attachment).video?).to be false
    end
  end

  describe 'counter_cache' do
    it 'increments and decrements baseball_note.media_attachments_count' do
      note = create(:baseball_note)
      attachment = create(:media_attachment, baseball_note: note, user: note.user)

      expect(note.reload.media_attachments_count).to eq 1

      attachment.destroy
      expect(note.reload.media_attachments_count).to eq 0
    end
  end

  describe 'after destroy' do
    it 'enqueues MediaAttachmentDeletionJob with the r2 keys' do
      attachment = create(:media_attachment, :video)
      expect { attachment.destroy }
        .to have_enqueued_job(MediaAttachmentDeletionJob).with(attachment.r2_key, attachment.thumbnail_r2_key)
    end
  end
end
