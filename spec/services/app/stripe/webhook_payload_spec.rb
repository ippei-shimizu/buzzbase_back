require 'rails_helper'

RSpec.describe App::Stripe::WebhookPayload do
  let(:fixture) do
    JSON.parse(Rails.root.join('spec/fixtures/stripe/checkout_session_completed.json').read)
  end
  let(:event) { Stripe::Event.construct_from(fixture) }
  let(:payload) { described_class.new(event) }

  describe 'event metadata getters' do
    it 'event_id を返す' do
      expect(payload.event_id).to eq('evt_test_checkout_completed_001')
    end

    it 'event_type を返す' do
      expect(payload.event_type).to eq('checkout.session.completed')
    end
  end

  describe '#data_object' do
    it 'data.object を Hash 風に返す' do
      expect(payload.data_object[:id]).to eq('cs_test_abc123')
      expect(payload.data_object[:customer]).to eq('cus_test_abc123')
    end
  end

  describe '#metadata' do
    it 'data.object.metadata を返す' do
      expect(payload.metadata[:user_id]).to eq('1')
      expect(payload.metadata[:plan]).to eq('monthly')
    end

    context 'metadata が空のとき' do
      let(:fixture) do
        base = JSON.parse(Rails.root.join('spec/fixtures/stripe/customer_subscription_deleted.json').read)
        base
      end

      it '空ハッシュを返す（nil safety）' do
        expect(payload.metadata).to eq({})
      end
    end
  end

  describe '#customer_id / #subscription_id' do
    it 'data.object から取得する' do
      expect(payload.customer_id).to eq('cus_test_abc123')
      expect(payload.subscription_id).to eq('sub_test_abc123')
    end
  end

  describe '#to_h' do
    it '元 event の to_hash を返す' do
      hash = payload.to_h
      expect(hash[:id]).to eq('evt_test_checkout_completed_001')
      expect(hash[:type]).to eq('checkout.session.completed')
    end
  end
end
