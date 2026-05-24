require 'rails_helper'

RSpec.describe TrialDaysCalculator do
  let(:user) { create(:user) }

  before do
    # 既存 ENV を上書きせず、テスト中だけ override する
    allow(ENV).to receive(:fetch).and_call_original
  end

  describe '.for(user, at:)' do
    context 'has_used_trial が true のとき' do
      before { user.subscription.update!(has_used_trial: true) }

      it '早期窓内でも 0 を返す（再加入はトライアル無し）' do
        days = described_class.for(user, at: Time.zone.parse('2026-06-01 12:00 JST'))
        expect(days).to eq(0)
      end

      it '早期窓外でも 0 を返す' do
        days = described_class.for(user, at: Time.zone.parse('2026-08-01 12:00 JST'))
        expect(days).to eq(0)
      end
    end

    context 'has_used_trial が false のとき' do
      it '早期窓内（2026-05-31 00:00 〜 06-06 23:59 JST）なら 30 を返す' do
        [
          Time.zone.parse('2026-05-31 00:00 JST'),
          Time.zone.parse('2026-06-03 12:00 JST'),
          Time.zone.parse('2026-06-06 23:59 JST')
        ].each do |at|
          expect(described_class.for(user, at:)).to eq(30)
        end
      end

      it '早期窓外（直前・直後）なら 7 を返す' do
        [
          Time.zone.parse('2026-05-30 23:59 JST'),
          Time.zone.parse('2026-06-07 00:00 JST'),
          Time.zone.parse('2026-08-01 12:00 JST')
        ].each do |at|
          expect(described_class.for(user, at:)).to eq(7)
        end
      end
    end
  end

  describe '.in_early_window?' do
    context 'ENV で窓を override したとき' do
      before do
        allow(ENV).to receive(:fetch).with('EARLY_SUBSCRIBER_WINDOW_START', any_args).and_return('2027-01-01 00:00')
        allow(ENV).to receive(:fetch).with('EARLY_SUBSCRIBER_WINDOW_END', any_args).and_return('2027-01-07 23:59')
      end

      it 'override 後の窓内なら true' do
        expect(described_class.in_early_window?(Time.zone.parse('2027-01-03 12:00 JST'))).to be(true)
      end

      it 'override 後の窓外なら false（デフォルト窓が無視される）' do
        expect(described_class.in_early_window?(Time.zone.parse('2026-06-01 12:00 JST'))).to be(false)
      end
    end

    it '引数を渡して時刻を明示できる' do
      expect(described_class.in_early_window?(Time.zone.parse('2026-06-01 12:00 JST'))).to be(true)
      expect(described_class.in_early_window?(Time.zone.parse('2026-08-01 12:00 JST'))).to be(false)
    end
  end
end
