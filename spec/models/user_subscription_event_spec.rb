require 'rails_helper'

RSpec.describe UserSubscriptionEvent, type: :model do
  describe 'バリデーション' do
    let(:user) { create(:user) }
    let(:subscription) { user.subscription }
    let(:base_attrs) do
      {
        user:,
        subscription:,
        event_type: 'initial_purchase',
        occurred_at: Time.current
      }
    end

    it '必須属性が揃っていれば valid' do
      expect(described_class.new(base_attrs)).to be_valid
    end

    it 'event_type が欠けていると invalid' do
      record = described_class.new(base_attrs.merge(event_type: nil))
      expect(record).not_to be_valid
      expect(record.errors[:event_type]).to be_present
    end

    it 'occurred_at が欠けていると invalid' do
      record = described_class.new(base_attrs.merge(occurred_at: nil))
      expect(record).not_to be_valid
      expect(record.errors[:occurred_at]).to be_present
    end

    it 'user が欠けていると invalid' do
      record = described_class.new(base_attrs.merge(user: nil))
      expect(record).not_to be_valid
    end
  end

  describe 'EVENT_TYPES 定数' do
    it 'Webhook handler が記録する全イベント名を含む' do
      expected = %w[
        initial_purchase
        trial_started
        purchased
        renewed
        cancelled
        expired
        refunded
        billing_issue
        recovered
        uncancelled
        product_changed
      ]
      expect(described_class::EVENT_TYPES).to match_array(expected)
    end
  end

  describe 'revenuecat_event_id の uniqueness' do
    let(:user) { create(:user) }

    it '同じ revenuecat_event_id で2回 create すると RecordNotUnique を発生させる' do
      described_class.create!(
        user:,
        subscription: user.subscription,
        event_type: 'initial_purchase',
        occurred_at: Time.current,
        revenuecat_event_id: 'evt_xyz_001'
      )

      expect do
        described_class.create!(
          user:,
          subscription: user.subscription,
          event_type: 'initial_purchase',
          occurred_at: Time.current,
          revenuecat_event_id: 'evt_xyz_001'
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '関連' do
    let(:user) { create(:user) }

    it 'user に belongs_to' do
      event = described_class.create!(
        user:,
        subscription: user.subscription,
        event_type: 'cancelled',
        occurred_at: Time.current
      )
      expect(event.user).to eq(user)
    end

    it 'subscription は optional（解約後の expired イベント等で nil 許容）' do
      event = described_class.create!(
        user:,
        subscription: nil,
        event_type: 'cancelled',
        occurred_at: Time.current
      )
      expect(event).to be_persisted
    end
  end
end
