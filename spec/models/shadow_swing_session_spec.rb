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

    it '完了済みセッションへの再実行では加算しない（リトライの冪等性）' do
      session = create(:shadow_swing_session, user:)
      session.complete!(swing_count: 100)

      expect { session.complete!(swing_count: 100) }
        .not_to(change { user.practice_logs.where(source: 'shadow_swing').sum(:amount) })
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

    it '「素振り」という回数単位の練習メニューが無ければ自動作成して紐付ける' do
      session = create(:shadow_swing_session, user:)

      expect { session.complete!(swing_count: 120) }
        .to change { user.practice_menus.where(name: '素振り', unit: 'count').count }.from(0).to(1)
      log = user.practice_logs.find_by(source: 'shadow_swing')
      expect(log.practice_menu).to eq(user.practice_menus.find_by(name: '素振り'))
    end

    it '既存の「素振り」メニューが回数単位なら紐付けて積み上げを統合する' do
      menu = create(:practice_menu, user:, name: '素振り', unit: 'count', unit_label: '回')
      session = create(:shadow_swing_session, user:)

      session.complete!(swing_count: 120)

      log = user.practice_logs.find_by(source: 'shadow_swing')
      expect(log.practice_menu).to eq(menu)
      expect(log.unit_label).to eq('回')
    end

    it '既存の「素振り」メニューが回数以外の単位なら紐付けない（統合しない）' do
      create(:practice_menu, user:, name: '素振り', unit: 'minutes')
      session = create(:shadow_swing_session, user:)

      session.complete!(swing_count: 120)

      log = user.practice_logs.find_by(source: 'shadow_swing')
      expect(log.practice_menu_id).to be_nil
      expect(log.unit_label).to eq('本')
    end
  end

  describe '#complete! の同時実行' do
    # 別スレッドの実コネクションから同じ練習ログ行を奪い合わせるため、テスト用トランザクションを外す。
    self.use_transactional_tests = false

    let(:today) { Time.find_zone('Asia/Tokyo').today }

    after { ActiveRecord::Base.connection.execute('TRUNCATE TABLE users CASCADE') }

    # sessions を同じタイミングで complete! させ、全スレッドの完了を待つ。
    def complete_concurrently(sessions, swing_count:)
      ready = Queue.new
      start = Queue.new
      threads = sessions.map do |session|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            session.complete!(swing_count:)
          end
        end
      end
      sessions.size.times { ready.pop }
      sessions.size.times { start << true }
      threads.each(&:join)
    end

    it '同日の複数セッションが同時に完了しても本数が失われず合算される' do
      create(:practice_menu, user:, name: '素振り', unit: 'count', unit_label: '本')
      # 既存ログと当日の activity_logs を先に作り、加算の競合だけを見る状態にする。
      create(:practice_log, :shadow_swing, user:, logged_on: today, amount: 100)
      sessions = Array.new(4) { create(:shadow_swing_session, user:, logged_on: today) }

      complete_concurrently(sessions, swing_count: 10)

      expect(user.practice_logs.where(source: 'shadow_swing').sum(:amount)).to eq(140)
    end

    it '当日のログが無い状態で複数セッションが同時に完了しても重複行を作らず合算される' do
      create(:practice_menu, user:, name: '素振り', unit: 'count', unit_label: '本')
      sessions = Array.new(4) { create(:shadow_swing_session, user:, logged_on: today) }

      complete_concurrently(sessions, swing_count: 10)

      logs = user.practice_logs.where(source: 'shadow_swing', logged_on: today)
      aggregate_failures do
        expect(logs.count).to eq(1)
        expect(logs.first.amount).to eq(40)
      end
    end

    it '素振りメニューが未作成の状態で複数セッションが同時に完了してもメニューは1件しか作られない' do
      sessions = Array.new(4) { create(:shadow_swing_session, user:, logged_on: today) }

      complete_concurrently(sessions, swing_count: 10)

      menus = user.practice_menus.where(name: described_class::MENU_NAME)
      log = user.practice_logs.find_by(source: 'shadow_swing', logged_on: today)
      aggregate_failures do
        expect(menus.count).to eq(1)
        expect(log.practice_menu_id).to eq(menus.first.id)
        expect(log.amount).to eq(40)
      end
    end
  end
end
