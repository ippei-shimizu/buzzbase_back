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

    context '同一イベントが同時到達し INSERT がユニーク制約に競合したとき' do
      let!(:existing) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: event_id,
               status: 'pending')
      end

      before do
        # find_or_create_by! の SELECT 時点では未登録 → INSERT 時に相手方が先に
        # コミット済み、という同時到達の敗者側を RecordNotUnique の raise で再現する。
        allow(described_class).to receive(:find_or_create_by!)
          .and_raise(ActiveRecord::RecordNotUnique)
      end

      it '例外にせず、先勝ちした既存レコードを返す' do
        result = described_class.find_or_create_pending!(
          provider: 'revenuecat',
          external_event_id: event_id,
          event_type: 'INITIAL_PURCHASE',
          payload:
        )

        expect(result.id).to eq(existing.id)
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

  describe '#claim_for_enqueue!' do
    context 'pending かつ enqueued_at が未設定のとき' do
      let(:webhook_event) { create(:webhook_event, status: 'pending', enqueued_at: nil) }

      it 'true を返し、enqueued_at を現在時刻にする' do
        expect(webhook_event.claim_for_enqueue!).to be(true)
        expect(webhook_event.reload.enqueued_at).to be_within(1.second).of(Time.current)
      end
    end

    context '同一レコードに対してほぼ同時に呼ばれたとき（近接同時配信の再現）' do
      let(:webhook_event) { create(:webhook_event, status: 'pending', enqueued_at: nil) }

      it '成功するのは1回だけで、2回目は false を返す（二重 enqueue 防止）' do
        # find_or_create_pending! の敗者側は別の WebhookEvent インスタンスとして
        # 同じレコードを参照するため、同一 id の別インスタンスで再現する。
        other_instance = described_class.find(webhook_event.id)

        expect(webhook_event.claim_for_enqueue!).to be(true)
        expect(other_instance.claim_for_enqueue!).to be(false)
      end
    end

    context 'enqueued_at が STALE_ENQUEUE_THRESHOLD を過ぎているとき（enqueue失敗・job ロストからの復旧）' do
      let(:webhook_event) do
        create(:webhook_event, status: 'pending',
                               enqueued_at: WebhookEvent::STALE_ENQUEUE_THRESHOLD.ago - 1.second)
      end

      it '再度 true を返し、enqueued_at を更新する（再送での復旧を許可する）' do
        expect(webhook_event.claim_for_enqueue!).to be(true)
      end
    end

    context 'enqueued_at がまだ新しいとき' do
      let(:webhook_event) do
        create(:webhook_event, status: 'pending',
                               enqueued_at: WebhookEvent::STALE_ENQUEUE_THRESHOLD.ago + 1.second)
      end

      it 'false を返す（enqueue済みの可能性があるため再enqueueしない）' do
        expect(webhook_event.claim_for_enqueue!).to be(false)
      end
    end

    context 'status が processed のとき' do
      let(:webhook_event) { create(:webhook_event, status: 'processed', enqueued_at: nil) }

      it 'false を返す' do
        expect(webhook_event.claim_for_enqueue!).to be(false)
      end
    end

    context 'status が failed のとき' do
      let(:webhook_event) { create(:webhook_event, status: 'failed', enqueued_at: nil) }

      it 'false を返す（failed からの再処理は手動re-enqueueに委ねる）' do
        expect(webhook_event.claim_for_enqueue!).to be(false)
      end
    end
  end
end
