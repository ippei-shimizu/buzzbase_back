require 'rails_helper'

RSpec.describe MediaAttachments::LimitValidator do
  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 30.days.from_now)
  end

  let(:user) { create(:user) }

  describe '#valid? for video' do
    it 'allows a free user at exactly 30 seconds / 480p' do
      attachment = build(:media_attachment, :video, duration_seconds: 30, height: 480)
      expect(described_class.new(user:, attachment:).valid?).to be true
    end

    it 'rejects a free user at 31 seconds' do
      attachment = build(:media_attachment, :video, duration_seconds: 31, height: 480)
      expect(described_class.new(user:, attachment:).valid?).to be false
    end

    it 'rejects a free user at 481px height' do
      attachment = build(:media_attachment, :video, duration_seconds: 30, height: 481)
      expect(described_class.new(user:, attachment:).valid?).to be false
    end

    it 'allows a Pro user at exactly 180 seconds / 1280px height' do
      make_pro(user)
      attachment = build(:media_attachment, :video, duration_seconds: 180, height: 1280)
      expect(described_class.new(user:, attachment:).valid?).to be true
    end

    it 'rejects a Pro user at 181 seconds' do
      make_pro(user)
      attachment = build(:media_attachment, :video, duration_seconds: 181, height: 1080)
      expect(described_class.new(user:, attachment:).valid?).to be false
    end

    it 'rejects a Pro user at 1281px height' do
      make_pro(user)
      attachment = build(:media_attachment, :video, duration_seconds: 180, height: 1281)
      expect(described_class.new(user:, attachment:).valid?).to be false
    end
  end

  describe '#valid? for image' do
    it 'allows a free user at exactly 5MB' do
      attachment = build(:media_attachment, file_size_bytes: 5.megabytes)
      expect(described_class.new(user:, attachment:).valid?).to be true
    end

    it 'rejects a free user over 5MB' do
      attachment = build(:media_attachment, file_size_bytes: 5.megabytes + 1)
      expect(described_class.new(user:, attachment:).valid?).to be false
    end

    it 'allows a Pro user at exactly 10MB' do
      make_pro(user)
      attachment = build(:media_attachment, file_size_bytes: 10.megabytes)
      expect(described_class.new(user:, attachment:).valid?).to be true
    end

    it 'rejects a Pro user over 10MB' do
      make_pro(user)
      attachment = build(:media_attachment, file_size_bytes: 10.megabytes + 1)
      expect(described_class.new(user:, attachment:).valid?).to be false
    end
  end
end
