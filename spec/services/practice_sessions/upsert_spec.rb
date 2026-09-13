require 'rails_helper'

RSpec.describe PracticeSessions::Upsert do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }
  let(:condition) { { fatigue_level: 4, physical_level: 2, sleep_hours: 6.5, mood: '普通' } }

  before { user.subscription.update!(status: 'active', expires_at: 1.month.from_now) }

  def call_upsert
    described_class.new(user:, logged_on: today, condition:).call
  end

  describe 'コンディションの upsert' do
    it '未登録の日はコンディションを新規作成する' do
      expect { call_upsert }.to change { user.condition_logs.count }.from(0).to(1)
      expect(user.condition_logs.find_by(logged_on: today).fatigue_level).to eq(4)
    end

    it '登録済みの日はコンディションを更新する' do
      create(:condition_log, user:, logged_on: today, fatigue_level: 1)

      expect { call_upsert }.not_to(change { user.condition_logs.count })
      expect(user.condition_logs.find_by(logged_on: today).fatigue_level).to eq(4)
    end

    context '無料ユーザーのとき' do
      before { user.subscription.update!(status: 'free', expires_at: nil) }

      it '疲労度・体調は保存し、Pro 限定の詳細項目は無視する' do
        call_upsert

        log = user.condition_logs.find_by(logged_on: today)
        aggregate_failures do
          expect(log.fatigue_level).to eq(4)
          expect(log.physical_level).to eq(2)
          expect(log.sleep_hours).to be_nil
          expect(log.mood).to be_nil
        end
      end

      it 'Pro 期間中に記録した詳細項目は上書きせず残す' do
        create(:condition_log, user:, logged_on: today, sleep_hours: 7.0, mood: '好調', memo: '快調')

        call_upsert

        log = user.condition_logs.find_by(logged_on: today)
        aggregate_failures do
          expect(log.fatigue_level).to eq(4)
          expect(log.sleep_hours).to eq(7.0)
          expect(log.mood).to eq('好調')
          expect(log.memo).to eq('快調')
        end
      end

      context 'Pro 限定の詳細項目だけが送られたとき' do
        let(:condition) { { sleep_hours: 6.5, mood: '普通' } }

        it '中身の無いコンディションを作らない' do
          expect { call_upsert }.not_to(change { user.condition_logs.count })
        end
      end
    end

    context '同時リクエストがユニーク制約に競合したとき' do
      # 相手方リクエストを別コネクションからコミットさせるため、テスト用トランザクションを外す。
      self.use_transactional_tests = false

      after { ActiveRecord::Base.connection.execute('TRUNCATE TABLE users CASCADE') }

      it '例外にせず先勝ちしたレコードを更新して成功する' do
        relation = user.condition_logs
        loser = relation.new(logged_on: today)
        allow(user).to receive(:condition_logs).and_return(relation)
        allow(relation).to receive(:find_or_initialize_by).and_return(loser)
        # 一意性バリデーションの SELECT を通過した直後に相手方が INSERT を確定させる、
        # という同時到達の敗者側を再現する。
        allow(loser).to receive(:valid?).and_wrap_original do |original, *args|
          result = original.call(*args)
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              ConditionLog.create!(user_id: user.id, logged_on: today, fatigue_level: 1)
            end
          end.join
          result
        end

        call_upsert

        logs = ConditionLog.where(user_id: user.id, logged_on: today)
        aggregate_failures do
          expect(logs.count).to eq(1)
          expect(logs.first.fatigue_level).to eq(4)
        end
      end
    end
  end
end
