require 'rails_helper'

RSpec.describe PracticeLog, type: :model do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  describe 'バリデーション' do
    it 'menu_name 必須' do
      log = build(:practice_log, user:, menu_name: nil)
      expect(log).not_to be_valid
    end

    it 'source は許可値のみ' do
      log = build(:practice_log, user:, source: 'invalid')
      expect(log).not_to be_valid
    end
  end

  describe 'activity_logs との連動' do
    it '作成すると当日の activity_log が再計算される' do
      expect do
        create(:practice_log, user:, logged_on: today)
      end.to change { ActivityLog.where(user:, activity_date: today).count }.from(0).to(1)
    end

    it '削除すると activity_log も再計算される（活動0なら削除）' do
      log = create(:practice_log, user:, logged_on: today)
      expect do
        log.destroy
      end.to change { ActivityLog.where(user:, activity_date: today).count }.from(1).to(0)
    end
  end
end
