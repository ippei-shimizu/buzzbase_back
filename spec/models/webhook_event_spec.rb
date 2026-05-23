require 'rails_helper'

RSpec.describe WebhookEvent, type: :model do
  describe '.find_or_create_pending!' do
    let(:event_id) { 'evt_abc123' }
    let(:payload) { { event: { id: event_id, type: 'INITIAL_PURCHASE' } } }

    context '同一 provider × external_event_id が未登録のとき' do
      it 'pending 状態で新規レコードを返す' do
        result = described_class.find_or_create_pending!(
          provider: 'revenuecat',
          external_event_id: event_id,
          event_type: 'INITIAL_PURCHASE',
          payload:
        )

        expect(result).to be_persisted
        expect(result.status).to eq('pending')
        expect(result.received_at).to be_within(1.second).of(Time.current)
        expect(result.payload['event']['id']).to eq(event_id)
      end
    end

    context '同一 provider × external_event_id が既に存在するとき' do
      let!(:existing) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: event_id,
               status: 'processed',
               processed_at: 1.hour.ago)
      end

      it '既存レコードを返し、status を pending に書き換えない' do
        result = described_class.find_or_create_pending!(
          provider: 'revenuecat',
          external_event_id: event_id,
          event_type: 'INITIAL_PURCHASE',
          payload:
        )

        expect(result.id).to eq(existing.id)
        expect(result.status).to eq('processed')
      end
    end
  end

  describe '#mark_processed!' do
    let(:webhook_event) { create(:webhook_event) }

    it 'status を processed に更新し、processed_at を現在時刻にする' do
      webhook_event.mark_processed!
      webhook_event.reload
      expect(webhook_event.status).to eq('processed')
      expect(webhook_event.processed_at).to be_within(1.second).of(Time.current)
      expect(webhook_event.error_message).to be_nil
    end
  end

  describe '#mark_failed!' do
    let(:webhook_event) { create(:webhook_event) }

    it 'status を failed に更新し、error_message を保存する' do
      webhook_event.mark_failed!('boom')
      expect(webhook_event.reload).to have_attributes(
        status: 'failed',
        error_message: 'boom'
      )
    end

    it 'error_message が nil なら例外メッセージなしで failed に更新する' do
      webhook_event.mark_failed!(nil)
      expect(webhook_event.reload).to have_attributes(
        status: 'failed',
        error_message: nil
      )
    end
  end

  describe '#pending?' do
    it 'status が pending のとき true を返す' do
      expect(build(:webhook_event, status: 'pending')).to be_pending
    end

    it 'status が processed のとき false を返す' do
      expect(build(:webhook_event, status: 'processed')).not_to be_pending
    end
  end
end
