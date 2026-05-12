require 'rails_helper'

RSpec.describe ManagementNoticePushJob, type: :job do
  describe '#perform' do
    context 'notice が存在し、notified_at が nil の場合' do
      let(:notice) { create(:management_notice, :published, notified_at: nil) }

      it 'PushNotificationService.send_to_all が呼び出される' do
        allow(PushNotificationService).to receive(:send_to_all)

        described_class.new.perform(notice.id)

        expect(PushNotificationService).to have_received(:send_to_all).with(
          title: 'BUZZ BASE お知らせ',
          body: notice.title
        )
      end

      it 'notified_at が現在時刻で更新される' do
        allow(PushNotificationService).to receive(:send_to_all)

        before_time = Time.current
        described_class.new.perform(notice.id)
        after_time = Time.current

        notified_at = notice.reload.notified_at
        expect(notified_at).to be_present
        expect(notified_at).to be_between(before_time, after_time)
      end
    end

    context 'notice の notified_at が既にセットされている場合' do
      let(:notice) { create(:management_notice, :published, notified_at: 1.day.ago) }

      it 'PushNotificationService.send_to_all は呼び出されない' do
        allow(PushNotificationService).to receive(:send_to_all)

        described_class.new.perform(notice.id)

        expect(PushNotificationService).not_to have_received(:send_to_all)
      end

      it 'notified_at は更新されない' do
        allow(PushNotificationService).to receive(:send_to_all)

        original = notice.notified_at
        described_class.new.perform(notice.id)

        expect(notice.reload.notified_at).to be_within(1.second).of(original)
      end
    end

    context 'notice が存在しない場合' do
      it '例外を raise せず graceful に終了する' do
        allow(PushNotificationService).to receive(:send_to_all)

        expect { described_class.new.perform(0) }.not_to raise_error
        expect(PushNotificationService).not_to have_received(:send_to_all)
      end
    end

    context 'PushNotificationService.send_to_all が例外を raise した場合' do
      let(:notice) { create(:management_notice, :published, notified_at: nil) }

      before do
        allow(PushNotificationService).to receive(:send_to_all).and_raise(StandardError, 'expo error')
      end

      it '例外が伝播し、notified_at は更新されない' do
        expect { described_class.new.perform(notice.id) }.to raise_error(StandardError, 'expo error')
        expect(notice.reload.notified_at).to be_nil
      end
    end
  end
end
