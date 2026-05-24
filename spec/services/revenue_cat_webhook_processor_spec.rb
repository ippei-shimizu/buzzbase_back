require 'rails_helper'

RSpec.describe RevenueCatWebhookProcessor do
  let(:event_id) { 'evt_initial_purchase_001' }
  let(:payload) do
    {
      'event' => {
        'id' => event_id,
        'type' => 'INITIAL_PURCHASE',
        'app_user_id' => 'user_1'
      }
    }
  end
  let(:webhook_event) do
    create(:webhook_event,
           provider: 'revenuecat',
           external_event_id: event_id,
           event_type: 'INITIAL_PURCHASE',
           payload:)
  end

  describe '#process' do
    subject(:process!) { described_class.new(webhook_event).process }

    context 'webhook_event がまだ pending のとき' do
      it 'status を processed に更新する' do
        expect { process! }.to change { webhook_event.reload.status }.from('pending').to('processed')
      end

      it 'processed_at をセットする' do
        process!
        expect(webhook_event.reload.processed_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'webhook_event が既に processed のとき' do
      let(:webhook_event) { create(:webhook_event, :processed, provider: 'revenuecat', external_event_id: event_id) }

      it '冪等性のため処理を実行しない（status を変えない）' do
        original_processed_at = webhook_event.processed_at
        process!
        expect(webhook_event.reload.processed_at).to be_within(1.second).of(original_processed_at)
      end
    end

    context 'handler 実装中に例外が発生したとき' do
      let(:processor) { described_class.new(webhook_event) }

      before do
        allow(processor).to receive(:handle_event).and_raise(StandardError, 'boom')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'webhook_event を failed 状態に遷移させて Sentry に通知し、例外を再 raise する' do
        expect { processor.process }.to raise_error(StandardError, 'boom')

        expect(Sentry).to have_received(:capture_exception).with(
          instance_of(StandardError),
          hash_including(tags: hash_including(source: 'revenuecat_webhook'))
        )
        expect(webhook_event.reload.status).to eq('failed')
        expect(webhook_event.error_message).to include('boom')
      end
    end

    context 'INITIAL_PURCHASE を受信したとき' do
      let(:user) { create(:user) }
      let(:fixture_name) { 'initial_purchase_normal' }
      let(:overrides) { {} }
      let(:payload) { revenuecat_payload_for(fixture_name, user:, **overrides) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      context 'period_type が NORMAL のとき' do
        it 'subscription を active 状態に遷移させ、product / platform / 期限を更新する' do
          process!
          subscription = user.reload.subscription
          expect(subscription).to have_attributes(
            status: 'active',
            plan_type: 'monthly',
            platform: 'ios',
            product_id: 'buzzbase_pro_monthly'
          )
          expect(subscription.started_at).to be_within(1.second).of(Time.zone.at(payload['event']['event_timestamp_ms'] / 1000))
          expect(subscription.expires_at).to be_within(1.second).of(Time.zone.at(payload['event']['expiration_at_ms'] / 1000))
        end

        it 'has_used_trial を立てない（通常購入はトライアル消化扱いにしない）' do
          process!
          expect(user.reload.subscription.has_used_trial).to be(false)
        end

        it 'revenuecat_user_id を Subscription にセットして次回以降の照合に使える状態にする' do
          process!
          expect(user.reload.subscription.revenuecat_user_id).to eq(user.id.to_s)
        end

        it 'UserSubscriptionEvent に initial_purchase イベントを記録する' do
          expect { process! }.to change { user.user_subscription_events.where(event_type: 'initial_purchase').count }.by(1)
        end
      end

      context 'period_type が TRIAL のとき' do
        let(:fixture_name) { 'initial_purchase_trial' }

        it 'subscription を trial 状態にし、has_used_trial を立てる' do
          process!
          subscription = user.reload.subscription
          expect(subscription.status).to eq('trial')
          expect(subscription.has_used_trial).to be(true)
        end

        it 'UserSubscriptionEvent に trial_started イベントを記録する' do
          expect { process! }.to change { user.user_subscription_events.where(event_type: 'trial_started').count }.by(1)
        end
      end

      context 'event_timestamp_ms が早期特典期間内のとき' do
        let(:overrides) do
          # 2026-06-01 12:00 JST → epoch ms
          { event_timestamp_ms: Time.zone.parse('2026-06-01 12:00 JST').to_i * 1000 }
        end

        it 'is_early_subscriber を true にする' do
          process!
          expect(user.reload.subscription.is_early_subscriber).to be(true)
        end
      end

      context 'event_timestamp_ms が早期特典期間外のとき' do
        let(:overrides) do
          { event_timestamp_ms: Time.zone.parse('2026-08-01 12:00 JST').to_i * 1000 }
        end

        it 'is_early_subscriber を false に保つ' do
          process!
          expect(user.reload.subscription.is_early_subscriber).to be(false)
        end
      end

      context '同一 event_id で 2 回受信されたとき' do
        it 'UserSubscriptionEvent は 1 件のまま（RecordNotUnique を握り潰す）' do
          described_class.new(webhook_event).process

          duplicated = create(:webhook_event,
                              provider: 'revenuecat',
                              external_event_id: "#{payload['event']['id']}-dup-wh",
                              event_type: payload['event']['type'],
                              payload:)
          described_class.new(duplicated).process

          expect(user.user_subscription_events.where(event_type: 'initial_purchase').count).to eq(1)
        end
      end

      context '未知の app_user_id を受信したとき' do
        let(:overrides) { { app_user_id: '9999999' } }

        it 'Sentry に warning を残し、Subscription を更新しない' do
          allow(Sentry).to receive(:capture_message)
          process!
          expect(Sentry).to have_received(:capture_message).with(
            a_string_including('user not found'),
            hash_including(level: :warning)
          )
          expect(user.reload.subscription.status).to eq('free')
          expect(webhook_event.reload.status).to eq('processed')
        end
      end
    end

    context 'RENEWAL を受信したとき' do
      let(:user) { create(:user) }
      let(:existing_expires_at) { Time.zone.parse('2026-07-01 12:00 JST') }
      let(:overrides) { {} }
      let(:payload) { revenuecat_payload_for('renewal', user:, **overrides) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      before do
        user.subscription.update!(
          status: 'active',
          plan_type: 'monthly',
          platform: 'ios',
          product_id: 'buzzbase_pro_monthly',
          revenuecat_user_id: user.id.to_s,
          has_used_trial: true,
          started_at: 30.days.ago,
          expires_at: existing_expires_at
        )
      end

      context '新しい expires_at が現状より後（通常のリニューアル）' do
        let(:overrides) do
          { expiration_at_ms: (existing_expires_at + 30.days).to_i * 1000 }
        end

        it 'expires_at を伸ばし status を active に保つ' do
          process!
          subscription = user.reload.subscription
          expect(subscription.expires_at).to be_within(1.second).of(existing_expires_at + 30.days)
          expect(subscription.status).to eq('active')
        end

        it 'UserSubscriptionEvent に renewed を記録する' do
          expect { process! }.to change { user.user_subscription_events.where(event_type: 'renewed').count }.by(1)
        end
      end

      context '古い expires_at（順序逆転で過去のイベントが届いた）' do
        let(:overrides) do
          { expiration_at_ms: (existing_expires_at - 10.days).to_i * 1000 }
        end

        it 'subscription.expires_at を巻き戻さない' do
          process!
          expect(user.reload.subscription.expires_at).to be_within(1.second).of(existing_expires_at)
        end

        it 'UserSubscriptionEvent も記録しない（純粋スキップ）' do
          expect { process! }.not_to(change { user.user_subscription_events.count })
        end
      end

      context 'billing_issue 状態からリニューアルが成功したとき' do
        before do
          user.subscription.update!(status: 'billing_issue', billing_issue_at: 1.day.ago)
        end

        let(:overrides) do
          { expiration_at_ms: (existing_expires_at + 30.days).to_i * 1000 }
        end

        it 'active に復帰し recovered イベントも記録する' do
          process!
          subscription = user.reload.subscription
          expect(subscription.status).to eq('active')
          expect(user.user_subscription_events.where(event_type: 'recovered').count).to eq(1)
        end
      end
    end

    context 'CANCELLATION を受信したとき' do
      let(:user) { create(:user) }
      let(:original_expires_at) { Time.zone.parse('2026-07-01 12:00 JST') }
      let(:payload) { revenuecat_payload_for('cancellation', user:) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      before do
        user.subscription.update!(
          status: 'active',
          plan_type: 'monthly',
          platform: 'ios',
          product_id: 'buzzbase_pro_monthly',
          revenuecat_user_id: user.id.to_s,
          has_used_trial: true,
          started_at: 30.days.ago,
          expires_at: original_expires_at
        )
      end

      it 'status を cancelled にし、expires_at は維持する' do
        process!
        subscription = user.reload.subscription
        expect(subscription.status).to eq('cancelled')
        expect(subscription.expires_at).to be_within(1.second).of(original_expires_at)
        expect(subscription.cancelled_at).to be_within(1.second).of(Time.current)
      end

      it 'UserSubscriptionEvent に cancelled を記録する' do
        expect { process! }.to change { user.user_subscription_events.where(event_type: 'cancelled').count }.by(1)
      end
    end

    context 'EXPIRATION を受信したとき' do
      let(:user) { create(:user) }
      let(:payload) { revenuecat_payload_for('expiration', user:) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      before do
        user.subscription.update!(
          status: 'cancelled',
          plan_type: 'monthly',
          platform: 'ios',
          product_id: 'buzzbase_pro_monthly',
          revenuecat_user_id: user.id.to_s,
          has_used_trial: true,
          started_at: 60.days.ago,
          expires_at: 1.day.ago,
          cancelled_at: 10.days.ago
        )
      end

      it 'status を expired に遷移させる' do
        process!
        expect(user.reload.subscription.status).to eq('expired')
      end

      it 'UserSubscriptionEvent に expired を記録する' do
        expect { process! }.to change { user.user_subscription_events.where(event_type: 'expired').count }.by(1)
      end
    end

    context 'BILLING_ISSUE を受信したとき' do
      let(:user) { create(:user) }
      let(:original_expires_at) { 5.days.from_now }
      let(:payload) { revenuecat_payload_for('billing_issue', user:) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      before do
        user.subscription.update!(
          status: 'active',
          plan_type: 'monthly',
          platform: 'ios',
          product_id: 'buzzbase_pro_monthly',
          revenuecat_user_id: user.id.to_s,
          has_used_trial: true,
          started_at: 30.days.ago,
          expires_at: original_expires_at
        )
      end

      it 'status を billing_issue にし、billing_issue_at をセット、expires_at を維持する' do
        process!
        subscription = user.reload.subscription
        expect(subscription.status).to eq('billing_issue')
        expect(subscription.billing_issue_at).to be_within(1.second).of(Time.current)
        expect(subscription.expires_at).to be_within(1.second).of(original_expires_at)
      end

      it 'UserSubscriptionEvent に billing_issue を記録する' do
        expect { process! }.to change { user.user_subscription_events.where(event_type: 'billing_issue').count }.by(1)
      end
    end

    context 'REFUND を受信したとき' do
      let(:user) { create(:user) }
      let(:payload) { revenuecat_payload_for('refund', user:) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      before do
        user.subscription.update!(
          status: 'active',
          plan_type: 'monthly',
          platform: 'ios',
          product_id: 'buzzbase_pro_monthly',
          revenuecat_user_id: user.id.to_s,
          has_used_trial: true,
          started_at: 30.days.ago,
          expires_at: 30.days.from_now
        )
      end

      it 'status を expired にし、expires_at を即時切れ、refunded_at をセットする' do
        process!
        subscription = user.reload.subscription
        expect(subscription.status).to eq('expired')
        expect(subscription.expires_at).to be_within(1.second).of(Time.current)
        expect(subscription.refunded_at).to be_within(1.second).of(Time.current)
      end

      it 'UserSubscriptionEvent に refunded を記録する' do
        expect { process! }.to change { user.user_subscription_events.where(event_type: 'refunded').count }.by(1)
      end
    end

    context 'UNCANCELLATION を受信したとき' do
      let(:user) { create(:user) }
      let(:payload) { revenuecat_payload_for('uncancellation', user:) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      context '直前が cancelled のとき' do
        before do
          user.subscription.update!(
            status: 'cancelled',
            plan_type: 'monthly',
            platform: 'ios',
            product_id: 'buzzbase_pro_monthly',
            revenuecat_user_id: user.id.to_s,
            has_used_trial: true,
            started_at: 30.days.ago,
            expires_at: 5.days.from_now,
            cancelled_at: 2.days.ago
          )
        end

        it 'active に戻し cancelled_at をクリアする' do
          process!
          subscription = user.reload.subscription
          expect(subscription.status).to eq('active')
          expect(subscription.cancelled_at).to be_nil
        end

        it 'UserSubscriptionEvent に uncancelled を記録する' do
          expect { process! }.to change { user.user_subscription_events.where(event_type: 'uncancelled').count }.by(1)
        end
      end

      context '直前が active で UNCANCELLATION 受信したとき（冪等性）' do
        before do
          user.subscription.update!(
            status: 'active',
            plan_type: 'monthly',
            platform: 'ios',
            revenuecat_user_id: user.id.to_s,
            has_used_trial: true,
            expires_at: 5.days.from_now
          )
        end

        it '状態を変えない' do
          expect { process! }.not_to(change { user.reload.subscription.attributes.except('updated_at', 'last_synced_at') })
        end
      end
    end

    context 'PRODUCT_CHANGE を受信したとき' do
      let(:user) { create(:user) }
      let(:payload) { revenuecat_payload_for('product_change', user:) }
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: payload['event']['id'],
               event_type: payload['event']['type'],
               payload:)
      end

      before do
        user.subscription.update!(
          status: 'active',
          plan_type: 'monthly',
          platform: 'ios',
          product_id: 'buzzbase_pro_monthly',
          revenuecat_user_id: user.id.to_s,
          has_used_trial: true,
          started_at: 30.days.ago,
          expires_at: 30.days.from_now
        )
      end

      it 'plan_type と product_id を新しい商品に切り替える' do
        process!
        subscription = user.reload.subscription
        expect(subscription.plan_type).to eq('yearly')
        expect(subscription.product_id).to eq('buzzbase_pro_yearly')
      end

      it 'UserSubscriptionEvent に product_changed を記録する' do
        expect { process! }.to change { user.user_subscription_events.where(event_type: 'product_changed').count }.by(1)
      end
    end

    context '未知の event_type を受信したとき' do
      let(:payload) do
        {
          'event' => {
            'id' => event_id,
            'type' => 'UNKNOWN_EVENT_TYPE',
            'app_user_id' => 'user_1'
          }
        }
      end
      let(:webhook_event) do
        create(:webhook_event,
               provider: 'revenuecat',
               external_event_id: event_id,
               event_type: 'UNKNOWN_EVENT_TYPE',
               payload:)
      end

      it 'Sentry に warning を残しつつ processed として記録する（未対応イベントもキャッシュに残す）' do
        allow(Sentry).to receive(:capture_message)

        process!

        expect(Sentry).to have_received(:capture_message).with(
          a_string_including('UNKNOWN_EVENT_TYPE'),
          hash_including(level: :warning)
        )
        expect(webhook_event.reload.status).to eq('processed')
      end
    end
  end
end
