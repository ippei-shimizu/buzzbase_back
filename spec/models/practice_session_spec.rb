require 'rails_helper'

RSpec.describe PracticeSession, type: :model do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  describe '.for' do
    it '同一ユーザー・同一日付では既存セッションを返す（重複作成しない）' do
      first = described_class.for(user, today)
      expect { described_class.for(user, today) }.not_to change(described_class, :count)
      expect(described_class.for(user, today)).to eq(first)
    end
  end

  describe '練習ログの自動ぶら下げ' do
    let!(:menu) { create(:practice_menu, user:) }

    it '単票でログを作ると当日の日次セッションへ自動で紐づく' do
      log = user.practice_logs.create!(practice_menu: menu, logged_on: today, amount: 100, menu_name: menu.name, source: 'manual')
      expect(log.practice_session).to be_present
      expect(log.practice_session.logged_on).to eq(today)
    end

    it '同日の複数ログは同一セッションに束ねられる' do
      log1 = user.practice_logs.create!(practice_menu: menu, logged_on: today, amount: 100, menu_name: menu.name, source: 'manual')
      log2 = user.practice_logs.create!(logged_on: today, amount: 50, menu_name: '素振り', source: 'shadow_swing')
      expect(log2.practice_session_id).to eq(log1.practice_session_id)
    end
  end

  describe '#condition_log' do
    it '同日のコンディションログを logged_on で引く' do
      session = described_class.for(user, today)
      condition = create(:condition_log, user:, logged_on: today)
      expect(session.condition_log).to eq(condition)
    end
  end
end
