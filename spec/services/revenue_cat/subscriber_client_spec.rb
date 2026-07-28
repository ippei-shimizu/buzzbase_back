require 'rails_helper'

RSpec.describe RevenueCat::SubscriberClient do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('REVENUECAT_SECRET_API_KEY').and_return('sk_test_dummy')
  end

  describe '#fetch_subscriber' do
    it 'returns the subscriber Hash on success' do
      response = instance_double(Net::HTTPOK, body: { subscriber: { 'entitlements' => {} } }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(response)

      result = described_class.new.fetch_subscriber('123')
      expect(result).to eq({ 'entitlements' => {} })
    end

    it 'raises RequestFailedError on a non-success response' do
      response = instance_double(Net::HTTPNotFound, code: '404')
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(Net::HTTP).to receive(:start).and_return(response)

      expect { described_class.new.fetch_subscriber('123') }.to raise_error(described_class::RequestFailedError)
    end
  end
end
