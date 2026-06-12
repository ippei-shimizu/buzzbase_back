# 試合記録アップデート用マスタテーブル群のタスク。
# - masters:reseed   — db/data/master_seeds/*.yml を再投入する（開発時用）
# - masters:snapshot — 既存データの件数と digest を出力（マイグレーション前後の比較用）

# 試合記録アップデートで導入したマスタ群。
# 順序は schema 依存しないが、ログ出力の見やすさのため固定する。
GAME_RECORD_MASTER_TABLES = %w[
  plate_results
  pitch_types
  contact_qualities
  timings
].freeze

namespace :masters do
  desc 'マスタテーブルを YAML から再投入する（開発時用。本番は db:migrate が自動投入）'
  task reseed: :environment do
    GAME_RECORD_MASTER_TABLES.each do |table|
      MasterData::Seeder.from_yaml(ActiveRecord::Base.connection, table:, file: "#{table}.yml")
      count = ActiveRecord::Base.connection.exec_query("SELECT COUNT(*) FROM #{table}").rows.first.first
      Rails.logger.debug { "Reseeded #{table} (#{count} rows)" }
    end
  end

  # snapshot タスクは、新カラムを enum 宣言したモデルがマイグレーション前の DB で
  # autoload されるとエラーになるため、ActiveRecord モデルを介さず生 SQL のみで実行する。
  desc '既存データのスナップショット（件数 + digest）を出力。マイグレーション前後の不変性確認に使う'
  task snapshot: :environment do
    require 'digest'
    conn = ActiveRecord::Base.connection

    %w[plate_appearances batting_averages match_results game_results pitching_results].each do |table|
      next unless conn.table_exists?(table)

      count = conn.exec_query("SELECT COUNT(*) FROM #{table}").rows.first.first
      puts "#{table}.count = #{count}"
    end

    if conn.table_exists?('batting_averages')
      ba_rows = conn.exec_query(<<~SQL.squish).rows
        SELECT id, at_bats, hit, two_base_hit, three_base_hit, home_run, total_bases,
               runs_batted_in, strike_out, base_on_balls, hit_by_pitch,
               sacrifice_hit, sacrifice_fly, stealing_base, caught_stealing, error
        FROM batting_averages ORDER BY id
      SQL
      puts "batting_averages digest = #{Digest::SHA256.hexdigest(ba_rows.to_s)}"
    end

    next unless conn.table_exists?('plate_appearances')

    %w[hit_direction_id plate_result_id batting_position_id batting_result].each do |col|
      rows = conn.exec_query("SELECT id, #{col} FROM plate_appearances ORDER BY id").rows
      puts "plate_appearances.#{col} digest = #{Digest::SHA256.hexdigest(rows.to_s)}"
    end
  end
end
