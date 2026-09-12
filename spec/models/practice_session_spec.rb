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

    it 'find_by が見逃した行を一意性バリデーションが検知した場合も既存セッションを返す' do
      winner = create(:practice_session, user:, logged_on: today)
      relation = user.practice_sessions
      allow(user).to receive(:practice_sessions).and_return(relation)
      # 相手方のコミットが find_by の後・バリデーションの前に入った同時到達を再現する。
      allow(relation).to receive(:find_by).and_return(nil, winner)

      expect(described_class.for(user, today)).to eq(winner)
    end

    it '一意制約と無関係な検証エラーは握り潰さずそのまま投げる' do
      expect { described_class.for(user, nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context 'PracticeSessions::Upsert の外側トランザクション内から同時に呼ばれたとき' do
      # 別スレッドの実コネクションから同じ日次セッション行を奪い合わせるため、テスト用トランザクションを外す。
      self.use_transactional_tests = false

      after { ActiveRecord::Base.connection.execute('TRUNCATE TABLE users CASCADE') }

      # 同じ日付への Upsert を同じタイミングで走らせ、発生した例外を集めて返す。
      def upsert_concurrently(count)
        errors = Queue.new
        ready = Queue.new
        start = Queue.new
        threads = Array.new(count) do |index|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              ready << true
              start.pop
              PracticeSessions::Upsert.new(user:, logged_on: today, memo: "振り返り#{index}").call
            rescue StandardError => e
              errors << e
            end
          end
        end
        count.times { ready.pop }
        count.times { start << true }
        threads.each(&:join)
        Array.new(errors.size) { errors.pop }
      end

      it '一意制約の競合から復旧し、セッションを1件だけ作って全リクエストが成功する' do
        errors = upsert_concurrently(4)

        aggregate_failures do
          # 失敗時に原因を追えるよう、件数ではなく例外の内容を突き合わせる。
          expect(errors.map { |e| "#{e.class}: #{e.message}" }).to be_empty
          expect(described_class.where(user_id: user.id, logged_on: today).count).to eq(1)
        end
      end
    end
  end

  describe 'practice_type' do
    it '既定は自主練習' do
      expect(described_class.for(user, today).practice_type).to eq('self_practice')
    end

    it '許可リストに無い種別は無効' do
      expect(build(:practice_session, user:, practice_type: 'unknown')).not_to be_valid
    end

    it '新規作成時のみ指定した種別が入る' do
      expect(described_class.for(user, today, practice_type: 'team_practice').practice_type).to eq('team_practice')
    end

    it '既存セッションがあれば種別を上書きしない' do
      create(:practice_session, user:, logged_on: today)

      expect(described_class.for(user, today, practice_type: 'team_practice').practice_type).to eq('self_practice')
    end
  end

  describe '練習ログの自動ぶら下げ' do
    let!(:menu) { create(:practice_menu, user:) }

    it '単票でログを作ると当日の日次セッションへ自動で紐づく' do
      log = user.practice_logs.create!(practice_menu: menu, logged_on: today, amount: 100, menu_name: menu.name, source: 'manual')
      expect(log.practice_session).to be_present
      expect(log.practice_session.logged_on).to eq(today)
    end

    it 'チーム練習・試合の予定から作られたログはその日をチーム練習として起こす' do
      schedule = create(:schedule, user:, event_type: 'practice')
      log = user.practice_logs.create!(practice_menu: menu, schedule:, logged_on: today, amount: 100,
                                       menu_name: menu.name, source: 'manual')

      expect(log.practice_session.practice_type).to eq('team_practice')
    end

    it '自主練習の予定から作られたログは自主練習のままにする' do
      schedule = create(:schedule, user:, event_type: 'self_practice')
      log = user.practice_logs.create!(practice_menu: menu, schedule:, logged_on: today, amount: 100,
                                       menu_name: menu.name, source: 'manual')

      expect(log.practice_session.practice_type).to eq('self_practice')
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
