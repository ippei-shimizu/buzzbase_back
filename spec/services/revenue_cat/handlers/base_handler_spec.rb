require 'rails_helper'

RSpec.describe RevenueCat::Handlers::BaseHandler do
  # BaseHandler は抽象クラスのため、with_resolved_subscription の共通フロー
  # （排他制御・未保存レコードの扱い）だけを検証する最小のサブクラスを定義する。
  let(:handler_class) do
    Class.new(described_class) do
      attr_reader :yielded_subscription

      def call
        with_resolved_subscription(require_persisted: false) do |_user, subscription|
          @yielded_subscription = subscription
          subscription.update!(last_synced_at: Time.current) if subscription.persisted?
        end
      end
    end
  end

  let(:user) { create(:user) }
  let(:payload) do
    RevenueCat::WebhookPayload.new(
      'event' => { 'id' => 'evt_lock_001', 'type' => 'RENEWAL', 'app_user_id' => user.id.to_s }
    )
  end

  before do
    allow(RevenueCat::UserResolver).to receive(:resolve).and_return(user)
  end

  describe '#with_resolved_subscription' do
    context 'subscription が永続化済みのとき' do
      before do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      end

      it 'with_lock で排他した上で本処理を実行する（webhook 二重配信時の lost update 防止）' do
        subscription = user.subscription_or_default
        allow(subscription).to receive(:with_lock).and_call_original

        handler_class.new(payload).call

        expect(subscription).to have_received(:with_lock)
        expect(subscription.reload.last_synced_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'subscription が未保存（無料ユーザー）のとき' do
      before do
        user.subscription&.destroy!
        user.reload
      end

      it 'ロック対象が存在しないため with_lock を経由せず本処理まで到達する' do
        handler = handler_class.new(payload)
        handler.call

        expect(handler.yielded_subscription).to be_present
        expect(handler.yielded_subscription).not_to be_persisted
      end
    end
  end
end
