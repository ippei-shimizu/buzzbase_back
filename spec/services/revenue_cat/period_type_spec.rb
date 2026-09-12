require 'rails_helper'

RSpec.describe RevenueCat::PeriodType do
  describe '.trial?' do
    it 'Webhookペイロード形式の大文字"TRIAL"でtrueを返す' do
      expect(described_class.trial?('TRIAL')).to be(true)
    end

    it 'REST API (GET /v1/subscribers) 形式の小文字"trial"でtrueを返す' do
      expect(described_class.trial?('trial')).to be(true)
    end

    it '"NORMAL"でfalseを返す' do
      expect(described_class.trial?('NORMAL')).to be(false)
    end

    it 'nilでfalseを返す' do
      expect(described_class.trial?(nil)).to be(false)
    end
  end
end
