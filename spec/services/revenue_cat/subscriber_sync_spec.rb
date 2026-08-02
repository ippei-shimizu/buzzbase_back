require 'rails_helper'

RSpec.describe RevenueCat::SubscriberSync do
  let(:user) { create(:user) }

  def stub_subscriber(hash)
    allow(RevenueCat::SubscriberClient).to receive(:fetch_subscriber).with(user.id.to_s).and_return(hash)
  end

  # entitlement/subscription detail をマージした最小限のsubscriberレスポンスを組み立てる。
  def stub_entitlement(entitlement_overrides: {}, subscription_overrides: {})
    stub_subscriber(
      'entitlements' => {
        'pro' => {
          'product_identifier' => 'jp.buzzbase.mobile.pro.monthly',
          'purchase_date' => 10.days.ago.iso8601,
          'expires_date' => 20.days.from_now.iso8601
        }.merge(entitlement_overrides)
      },
      'subscriptions' => {
        'jp.buzzbase.mobile.pro.monthly' => { 'store' => 'app_store', 'period_type' => 'NORMAL' }.merge(subscription_overrides)
      }
    )
  end

  describe '#call' do
    context 'entitlementが存在しない場合' do
      it '一度も加入していなければ free のままにする' do
        stub_subscriber({})
        subscription = described_class.new(user).call
        expect(subscription.status).to eq('free')
      end

      it '過去に加入していれば expired にする' do
        user.subscription.update!(status: 'active', product_id: 'jp.buzzbase.mobile.pro.monthly')
        stub_subscriber({})
        subscription = described_class.new(user).call
        expect(subscription.status).to eq('expired')
      end
    end

    context 'entitlementが存在する場合' do
      it 'アクティブな加入をactiveとして反映する' do
        stub_entitlement
        subscription = described_class.new(user).call

        aggregate_failures do
          expect(subscription.status).to eq('active')
          expect(subscription.plan_type).to eq('monthly')
          expect(subscription.platform).to eq('ios')
          expect(subscription.product_id).to eq('jp.buzzbase.mobile.pro.monthly')
          expect(subscription.last_synced_at).to be_present
        end
      end

      it 'period_type が TRIAL なら trial として反映する' do
        stub_entitlement(subscription_overrides: { 'period_type' => 'TRIAL' })
        subscription = described_class.new(user).call

        aggregate_failures do
          expect(subscription.status).to eq('trial')
          expect(subscription.has_used_trial).to be true
        end
      end

      it '期限切れ(グレース期間もなし)なら expired にする' do
        stub_entitlement(entitlement_overrides: { 'expires_date' => 1.day.ago.iso8601 })
        subscription = described_class.new(user).call
        expect(subscription.status).to eq('expired')
      end

      it '期限切れでもグレース期間内ならactiveのまま扱い、pro_active?も維持する' do
        stub_entitlement(
          entitlement_overrides: {
            'expires_date' => 1.day.ago.iso8601,
            'grace_period_expires_date' => 5.days.from_now.iso8601
          }
        )
        subscription = described_class.new(user).call

        aggregate_failures do
          expect(subscription.status).to eq('active')
          # expires_atにグレース期限ではなく本来のexpires_dateだけを保存すると、
          # pro_active?/in_grace_period?が期限切れ判定してしまい、statusと矛盾する。
          expect(subscription.pro_active?).to be true
          expect(subscription.expires_at).to be > Time.current
        end
      end

      it 'billing_issues_detected_atがあればbilling_issueにする' do
        stub_entitlement(subscription_overrides: { 'billing_issues_detected_at' => 1.day.ago.iso8601 })
        subscription = described_class.new(user).call

        aggregate_failures do
          expect(subscription.status).to eq('billing_issue')
          expect(subscription.billing_issue_at).to be_present
        end
      end

      it 'unsubscribe_detected_atがあればcancelledにする' do
        stub_entitlement(subscription_overrides: { 'store' => 'stripe', 'unsubscribe_detected_at' => 1.day.ago.iso8601 })
        subscription = described_class.new(user).call

        aggregate_failures do
          expect(subscription.status).to eq('cancelled')
          expect(subscription.platform).to eq('web')
          expect(subscription.cancelled_at).to be_present
        end
      end

      it 'PlanCatalogに未登録のproduct_idの場合は更新をスキップしSentryへ警告する' do
        stub_entitlement(entitlement_overrides: { 'product_identifier' => 'unknown_product' })
        allow(Sentry).to receive(:capture_message)

        subscription = described_class.new(user).call

        expect(subscription.status).to eq('free')
        expect(subscription.plan_type).to be_nil
        expect(Sentry).to have_received(:capture_message).with(/unknown product_id/, level: :warning)
      end

      it 'PlanCatalogに未登録のstoreの場合は更新をスキップしSentryへ警告する' do
        stub_entitlement(subscription_overrides: { 'store' => 'unknown_store' })
        allow(Sentry).to receive(:capture_message)

        subscription = described_class.new(user).call

        expect(subscription.status).to eq('free')
        expect(subscription.platform).to be_nil
        expect(Sentry).to have_received(:capture_message).with(/unknown product_id/, level: :warning)
      end
    end
  end
end
