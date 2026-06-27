require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe '#pro_active?' do
    it 'returns false for free status' do
      subscription = build(:subscription, :free)
      expect(subscription.pro_active?).to be false
    end

    it 'returns true for active status within expiration' do
      subscription = build(:subscription, :active)
      expect(subscription.pro_active?).to be true
    end

    it 'returns true for trial status within expiration' do
      subscription = build(:subscription, :trial)
      expect(subscription.pro_active?).to be true
    end

    it 'returns true for cancelled status within expiration' do
      subscription = build(:subscription, :cancelled)
      expect(subscription.pro_active?).to be true
    end

    it 'returns true for billing_issue status within expiration' do
      subscription = build(:subscription, :billing_issue)
      expect(subscription.pro_active?).to be true
    end

    it 'returns false for expired status' do
      subscription = build(:subscription, :expired)
      expect(subscription.pro_active?).to be false
    end

    it 'returns false for pending status (purchase in progress, not yet confirmed)' do
      subscription = build(:subscription, :pending)
      expect(subscription.pro_active?).to be false
    end

    it 'returns false when expires_at is in the past even with active status' do
      subscription = build(:subscription, :active, expires_at: 1.minute.ago)
      expect(subscription.pro_active?).to be false
    end

    it 'returns true when expires_at is nil and status is active' do
      subscription = build(:subscription, :active, expires_at: nil)
      expect(subscription.pro_active?).to be true
    end
  end

  describe '#in_trial?' do
    it 'returns true for trial status within expiration' do
      subscription = build(:subscription, :trial)
      expect(subscription.in_trial?).to be true
    end

    it 'returns false for non-trial status even within Pro period' do
      subscription = build(:subscription, :active)
      expect(subscription.in_trial?).to be false
    end

    it 'returns false for trial whose expires_at has passed' do
      subscription = build(:subscription, :trial, expires_at: 1.minute.ago)
      expect(subscription.in_trial?).to be false
    end
  end

  describe '#in_grace_period?' do
    it 'returns true for cancelled within expiration' do
      expect(build(:subscription, :cancelled).in_grace_period?).to be true
    end

    it 'returns true for billing_issue within expiration' do
      expect(build(:subscription, :billing_issue).in_grace_period?).to be true
    end

    # クライアントが in_grace_period を Pro アクセス判定に使うため、
    # 期限切れの cancelled / billing_issue で true を返してはならない
    it 'returns false for cancelled whose expires_at has passed' do
      subscription = build(:subscription, :cancelled, expires_at: 1.minute.ago)
      expect(subscription.in_grace_period?).to be false
    end

    it 'returns false for billing_issue whose expires_at has passed' do
      subscription = build(:subscription, :billing_issue, expires_at: 1.minute.ago)
      expect(subscription.in_grace_period?).to be false
    end

    it 'returns false for active' do
      expect(build(:subscription, :active).in_grace_period?).to be false
    end

    it 'returns false for free' do
      expect(build(:subscription, :free).in_grace_period?).to be false
    end
  end

  describe '#days_remaining' do
    it 'returns the integer days until expires_at' do
      subscription = build(:subscription, :active, expires_at: 10.days.from_now)
      expect(subscription.days_remaining).to eq 10
    end

    it 'returns 0 when expires_at is in the past' do
      subscription = build(:subscription, :active, expires_at: 1.day.ago)
      expect(subscription.days_remaining).to eq 0
    end

    it 'returns nil when expires_at is nil' do
      subscription = build(:subscription, :free, expires_at: nil)
      expect(subscription.days_remaining).to be_nil
    end
  end

  describe '#can_use_trial?' do
    it 'returns true when has_used_trial is false' do
      subscription = build(:subscription, :free, has_used_trial: false)
      expect(subscription.can_use_trial?).to be true
    end

    it 'returns false when has_used_trial is true' do
      subscription = build(:subscription, :expired, has_used_trial: true)
      expect(subscription.can_use_trial?).to be false
    end
  end

  # User の after_create で必ず free な subscription が生成されるため、
  # 同じユーザーに 2 つ目の subscription を作るとユニーク制約に当たる。
  # ファクトリ側で「既存 subscription を attributes で上書きする」戦略が
  # 正しく動いていることを保証する。
  describe 'factory create behavior' do
    it 'reuses the auto-created free subscription when create(:subscription, :active) is called' do
      subscription = create(:subscription, :active)
      expect(described_class.where(user_id: subscription.user_id).count).to eq 1
      expect(subscription.status).to eq 'active'
      expect(subscription.expires_at).to be > Time.current
    end

    it 'does not raise unique constraint violation on create' do
      expect { create(:subscription, :trial) }.not_to raise_error
    end
  end
end
