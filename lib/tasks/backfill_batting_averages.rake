namespace :data do
  # PlateAppearance の callback 化（Issue #388）以前に runner / 一括投入スクリプト等で
  # 直接作られた新仕様 PA に対して、対応する batting_averages が作られていない試合を
  # 救済するためのバックフィル。recalculator を全試合に流し、混在試合・旧仕様試合は
  # new_format_game? が false を返すため自動的に skip される。
  #
  # 実行例:
  #   docker compose exec back bundle exec rails data:backfill_batting_averages DRY_RUN=1
  #   docker compose exec back bundle exec rails data:backfill_batting_averages
  #   heroku run bundle exec rails data:backfill_batting_averages
  desc '全試合の batting_average を再集計する（新仕様試合のみ対象、混在/旧仕様は skip）'
  task backfill_batting_averages: :environment do
    dry_run = ENV['DRY_RUN'].present?
    total = GameResult.count
    puts "対象試合数: #{total}"

    scanned = 0
    recalculated = 0
    skipped = 0

    GameResult.find_each(batch_size: 200) do |game_result|
      scanned += 1
      if dry_run
        has_new_pa = PlateAppearance.exists?(game_result_id: game_result.id, is_new_format: true)
        has_old_pa = PlateAppearance.exists?(game_result_id: game_result.id, is_new_format: false)
        if has_new_pa && !has_old_pa
          recalculated += 1
        else
          skipped += 1
        end
      else
        result = Stats::BattingAverageRecalculator.new(
          game_result_id: game_result.id, user_id: game_result.user_id, cleanup_orphan: false
        ).call
        result ? recalculated += 1 : skipped += 1
      end
    end

    suffix = dry_run ? '再集計可能と判定' : '再集計しました'
    puts "対象 #{scanned}/#{total} 件中 #{recalculated} 件を#{suffix}（skip: #{skipped}）。"
  end
end
