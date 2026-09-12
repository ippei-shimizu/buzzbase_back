require 'rails_helper'

RSpec.describe PushNotificationJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }

    it 'PushNotificationService.send_to_user に委譲する' do
      allow(PushNotificationService).to receive(:send_to_user)

      described_class.perform_now(user.id, title: 'BUZZ BASE', body: 'テスト通知')

      expect(PushNotificationService).to have_received(:send_to_user)
        .with(user, title: 'BUZZ BASE', body: 'テスト通知')
    end

    it 'ユーザーが存在しない場合は送信しない' do
      allow(PushNotificationService).to receive(:send_to_user)

      described_class.perform_now(0, title: 'BUZZ BASE', body: 'テスト通知')

      expect(PushNotificationService).not_to have_received(:send_to_user)
    end
  end
end
