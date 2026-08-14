class BackfillPracticeTypeOnPracticeSessions < ActiveRecord::Migration[7.1]
  # 予定チェックから生まれたログを持つ日は、その予定の種別をその日の種別とみなす。
  # PracticeLog#assign_practice_session の推論と同じルール。
  def up
    execute(<<-SQL.squish)
      UPDATE practice_sessions SET practice_type = 'team_practice', updated_at = NOW()
      WHERE EXISTS (
        SELECT 1 FROM practice_logs
        JOIN schedules ON schedules.id = practice_logs.schedule_id
        WHERE practice_logs.practice_session_id = practice_sessions.id
          AND schedules.event_type IN ('practice', 'game')
      )
    SQL
  end

  def down
    # 変更前の練習種別を保持していないため書き戻せない。巻き戻しはカラム削除で行う。
  end
end
