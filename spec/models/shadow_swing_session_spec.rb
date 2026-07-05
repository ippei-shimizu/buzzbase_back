require 'rails_helper'

RSpec.describe ShadowSwingSession, type: :model do
  let(:user) { create(:user) }

  describe '#complete!' do
    it '素振り由来の練習ログを作成し本数を記録する' do
      session = create(:shadow_swing_session, user:)

      expect { session.complete!(swing_count: 120) }
        .to change { user.practice_logs.where(source: 'shadow_swing').count }.by(1)
      log = user.practice_logs.find_by(source: 'shadow_swing')
      expect(log.amount).to eq(120)
      expect(session.reload.swing_count).to eq(120)
    end

    it '同じ日に複数回完了すると1レコードに加算される' do
      today = Time.find_zone('Asia/Tokyo').today
      create(:shadow_swing_session, user:, logged_on: today).complete!(swing_count: 100)
      create(:shadow_swing_session, user:, logged_on: today).complete!(swing_count: 50)

      logs = user.practice_logs.where(source: 'shadow_swing', logged_on: today)
      aggregate_failures do
        expect(logs.count).to eq(1)
        expect(logs.first.amount).to eq(150)
      end
    end
  end
end
