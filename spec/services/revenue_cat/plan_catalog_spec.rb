require 'rails_helper'

RSpec.describe RevenueCat::PlanCatalog do
  describe '.plan_type_from' do
    context 'モバイルの固定文字列product_idのとき' do
      it '月額product_idからmonthlyを返す' do
        expect(described_class.plan_type_from('jp.buzzbase.mobile.pro.monthly')).to eq('monthly')
      end

      it '年額product_idからyearlyを返す' do
        expect(described_class.plan_type_from('jp.buzzbase.mobile.pro.yearly')).to eq('yearly')
      end
    end

    context 'StripeのProduct IDのとき' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('STRIPE_PRODUCT_ID_MONTHLY', nil).and_return('prod_monthly_test')
        allow(ENV).to receive(:fetch).with('STRIPE_PRODUCT_ID_YEARLY', nil).and_return('prod_yearly_test')
      end

      it 'STRIPE_PRODUCT_ID_MONTHLYと一致するproduct_idからmonthlyを返す' do
        expect(described_class.plan_type_from('prod_monthly_test')).to eq('monthly')
      end

      it 'STRIPE_PRODUCT_ID_YEARLYと一致するproduct_idからyearlyを返す' do
        expect(described_class.plan_type_from('prod_yearly_test')).to eq('yearly')
      end
    end

    context 'product_idがnilで、STRIPE_PRODUCT_ID_MONTHLY/YEARLYが未設定のとき' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('STRIPE_PRODUCT_ID_MONTHLY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('STRIPE_PRODUCT_ID_YEARLY', nil).and_return(nil)
      end

      it 'nil同士の一致で誤ってmonthlyと判定せずnilを返す' do
        expect(described_class.plan_type_from(nil)).to be_nil
      end
    end

    context '未知のproduct_idのとき' do
      it 'nilを返す' do
        expect(described_class.plan_type_from('unknown_product')).to be_nil
      end
    end
  end

  describe '.platform_from' do
    it 'APP_STOREからiosを返す' do
      expect(described_class.platform_from('APP_STORE')).to eq('ios')
    end

    it 'MAC_APP_STOREからiosを返す' do
      expect(described_class.platform_from('MAC_APP_STORE')).to eq('ios')
    end

    it 'PLAY_STOREからandroidを返す' do
      expect(described_class.platform_from('PLAY_STORE')).to eq('android')
    end

    it 'STRIPEからwebを返す' do
      expect(described_class.platform_from('STRIPE')).to eq('web')
    end

    it '未知のstoreのときnilを返す' do
      expect(described_class.platform_from('UNKNOWN_STORE')).to be_nil
    end
  end
end
