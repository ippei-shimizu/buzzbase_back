class AddPracticeSessionRefToPracticeLogs < ActiveRecord::Migration[7.1]
  def up
    add_reference :practice_logs, :practice_session, foreign_key: true, null: true

    # 既存の練習ログを (user_id, logged_on) ごとに日次セッションへ束ねる。
    execute(<<~SQL.squish)
      INSERT INTO practice_sessions (user_id, logged_on, created_at, updated_at)
      SELECT user_id, logged_on, MIN(created_at), MAX(updated_at)
      FROM practice_logs
      GROUP BY user_id, logged_on
    SQL

    execute(<<~SQL.squish)
      UPDATE practice_logs
      SET practice_session_id = practice_sessions.id
      FROM practice_sessions
      WHERE practice_logs.user_id = practice_sessions.user_id
        AND practice_logs.logged_on = practice_sessions.logged_on
    SQL
  end

  def down
    remove_reference :practice_logs, :practice_session, foreign_key: true
  end
end
