namespace :ranking do
  desc 'Record daily ranking snapshots for all groups (JST date)'
  task snapshot_daily: :environment do
    jst_date = Time.current.in_time_zone('Tokyo').to_date

    puts "Recording ranking snapshots for #{jst_date}..."
    begin
      GroupRankingSnapshotService.record_all(date: jst_date)
      puts 'Ranking snapshot completed successfully!'
    rescue StandardError => e
      puts "Ranking snapshot failed: #{e.message}"
      Rails.logger.error("Ranking snapshot failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise e
    end
  end
end
