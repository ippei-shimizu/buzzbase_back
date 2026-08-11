class AddUniqueIndexToShadowSwingPracticeLogs < ActiveRecord::Migration[7.1]
  INDEX_NAME = 'index_practice_logs_on_user_logged_on_shadow_swing'.freeze
  TARGET_CONDITION = "source = 'shadow_swing'".freeze

  # shadow_swing 由来のログは同日1レコードへ集約する設計だが、このインデックス追加まで
  # DB制約が無く、初回セッションの同時完了で重複行がサイレントに作られうる期間があった
  # （ShadowSwingSession#practice_log_for 参照）。source ごとに集約単位が異なる
  # （manual は同日複数メニューを許容）ため、部分インデックスで shadow_swing のみ
  # (user_id, logged_on) を一意にする。適用前に既存の重複を1件へ合算しておく。
  def up
    merge_duplicated_shadow_swing_logs
    add_index :practice_logs, %i[user_id logged_on], unique: true, where: TARGET_CONDITION, name: INDEX_NAME
  end

  def down
    remove_index :practice_logs, name: INDEX_NAME
  end

  private

  # amount は ShadowSwingSession#practice_log_for が通常時に行う「同日ログへの加算」と
  # 同じ意味論で合算し、切り捨てない。外部参照（shadow_swing_sessions / baseball_notes）は
  # 最古の1件（keeper）へ付け替えてから敗者行を削除する。
  def merge_duplicated_shadow_swing_logs
    execute(<<-SQL.squish)
      UPDATE practice_logs AS keeper
      SET amount = keeper.amount + losers.total_amount
      FROM (
        SELECT ranked.keeper_id, SUM(pl.amount) AS total_amount
        FROM practice_logs pl
        JOIN (#{ranked_logs_sql}) AS ranked ON ranked.id = pl.id
        WHERE ranked.id <> ranked.keeper_id
        GROUP BY ranked.keeper_id
      ) AS losers
      WHERE keeper.id = losers.keeper_id
    SQL

    %w[shadow_swing_sessions baseball_notes].each do |table|
      execute(<<-SQL.squish)
        UPDATE #{table} SET practice_log_id = ranked.keeper_id
        FROM (#{ranked_logs_sql}) AS ranked
        WHERE #{table}.practice_log_id = ranked.id AND ranked.id <> ranked.keeper_id
      SQL
    end

    execute(<<-SQL.squish)
      DELETE FROM practice_logs
      USING (#{ranked_logs_sql}) AS ranked
      WHERE practice_logs.id = ranked.id AND ranked.id <> ranked.keeper_id
    SQL
  end

  def ranked_logs_sql
    <<-SQL.squish
      SELECT id, FIRST_VALUE(id) OVER (PARTITION BY user_id, logged_on ORDER BY id) AS keeper_id
      FROM practice_logs WHERE #{TARGET_CONDITION}
    SQL
  end
end
