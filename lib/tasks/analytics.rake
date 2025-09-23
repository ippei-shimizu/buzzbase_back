namespace :analytics do
  desc '指定日の日次統計データを計算'
  task :calculate_daily, [:date] => :environment do |_task, args|
    date = args[:date] ? Date.parse(args[:date]) : Date.current

    puts "Calculating daily statistics for #{date}..."

    begin
      stats = Admin::DailyStatistic.calculate_for_date(date)
      puts 'Statistics calculated successfully:'
      puts "  Total Users: #{stats.total_users}"
      puts "  Active Users: #{stats.active_users}"
      puts "  New Users: #{stats.new_users}"
      puts "  Total Games: #{stats.total_games}"
      puts "  Total Posts: #{stats.total_posts}"
    rescue StandardError => e
      puts "Error calculating statistics: #{e.message}"
      raise e
    end
  end

  desc '期間指定で日次統計データを一括計算'
  task :calculate_batch, %i[start_date end_date] => :environment do |_task, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 7.days.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current

    puts "Calculating daily statistics from #{start_date} to #{end_date}..."

    begin
      Admin::DailyStatistic.calculate_batch(start_date, end_date)
      puts 'Batch calculation completed successfully!'
    rescue StandardError => e
      puts "Error during batch calculation: #{e.message}"
      raise e
    end
  end

  desc '指定日の週次統計データを計算'
  task :calculate_weekly, [:date] => :environment do |_task, args|
    date = args[:date] ? Date.parse(args[:date]) : Date.current

    puts "Calculating weekly statistics for week of #{date}..."

    begin
      stats = Admin::WeeklyStatistic.calculate_for_week(date)
      puts 'Weekly statistics calculated successfully:'
      puts "  Week: #{stats.week_start_date} to #{stats.week_end_date}"
      puts "  Total Users: #{stats.total_users}"
      puts "  Avg Daily Active Users: #{stats.avg_daily_active_users}"
      puts "  Peak Daily Active Users: #{stats.peak_daily_active_users}"
      puts "  New Users: #{stats.new_users}"
      puts "  Total Games: #{stats.total_games}"
      puts "  Total Batting Records: #{stats.total_batting_records}"
      puts "  Total Pitching Records: #{stats.total_pitching_records}"
      puts "  Weekly Retention Rate: #{stats.weekly_retention_rate}%"
      puts "  User Growth Rate: #{stats.user_growth_rate}%"
    rescue StandardError => e
      puts "Error calculating weekly statistics: #{e.message}"
      raise e
    end
  end

  desc '指定日の月次統計データを計算'
  task :calculate_monthly, [:date] => :environment do |_task, args|
    date = args[:date] ? Date.parse(args[:date]) : Date.current

    puts "Calculating monthly statistics for #{date.strftime('%Y-%m')}..."

    begin
      stats = Admin::MonthlyStatistic.calculate_for_month(date)
      puts 'Monthly statistics calculated successfully:'
      puts "  Month: #{stats.year}/#{stats.month}"
      puts "  Total Users: #{stats.total_users}"
      puts "  Avg Daily Active Users: #{stats.avg_daily_active_users}"
      puts "  Peak Daily Active Users: #{stats.peak_daily_active_users}"
      puts "  Avg Weekly Active Users: #{stats.avg_weekly_active_users}"
      puts "  New Users: #{stats.new_users}"
      puts "  Total Games: #{stats.total_games}"
      puts "  Total Batting Records: #{stats.total_batting_records}"
      puts "  Total Pitching Records: #{stats.total_pitching_records}"
      puts "  Monthly Retention Rate: #{stats.monthly_retention_rate}%"
      puts "  User Growth Rate: #{stats.user_growth_rate}%"
      puts "  Engagement Score: #{stats.engagement_score}"
    rescue StandardError => e
      puts "Error calculating monthly statistics: #{e.message}"
      raise e
    end
  end

  desc '期間指定で週次統計データを一括計算'
  task :calculate_weekly_batch, %i[start_date end_date] => :environment do |_task, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 4.weeks.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current

    puts "Calculating weekly statistics from #{start_date} to #{end_date}..."

    begin
      Admin::WeeklyStatistic.calculate_batch(start_date, end_date)
      puts 'Weekly batch calculation completed successfully!'
    rescue StandardError => e
      puts "Error during weekly batch calculation: #{e.message}"
      raise e
    end
  end

  desc '期間指定で月次統計データを一括計算'
  task :calculate_monthly_batch, %i[start_date end_date] => :environment do |_task, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 6.months.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current

    puts "Calculating monthly statistics from #{start_date} to #{end_date}..."

    begin
      Admin::MonthlyStatistic.calculate_batch(start_date, end_date)
      puts 'Monthly batch calculation completed successfully!'
    rescue StandardError => e
      puts "Error during monthly batch calculation: #{e.message}"
      raise e
    end
  end

  # === Job-based Tasks ===
  desc '昨日分の日次統計Jobを実行'
  task daily_job: :environment do
    target_date = Date.current - 1.day
    puts "Running daily statistics job for #{target_date}..."

    begin
      result = Admin::Analytics::DailyStatisticsJob.new.perform(target_date)
      puts 'Job completed successfully!'
      puts "Date: #{result[:date]}"
      puts "Total Users: #{result[:stats].total_users}"
      puts "Active Users: #{result[:stats].active_users}"
      puts "New Users: #{result[:stats].new_users}"
    rescue StandardError => e
      puts "Job failed: #{e.message}"
      raise e
    end
  end

  desc '指定日の日次統計Jobを実行'
  task :daily_job_for_date, [:date] => :environment do |_task, args|
    target_date = args[:date] ? Date.parse(args[:date]) : Date.current - 1.day
    puts "Running daily statistics job for #{target_date}..."

    begin
      result = Admin::Analytics::DailyStatisticsJob.new.perform(target_date)
      puts 'Job completed successfully!'
      puts "Date: #{result[:date]}"
      puts "Total Users: #{result[:stats].total_users}"
      puts "Active Users: #{result[:stats].active_users}"
      puts "New Users: #{result[:stats].new_users}"
    rescue StandardError => e
      puts "Job failed: #{e.message}"
      raise e
    end
  end

  desc '期間指定で日次統計Jobを一括実行'
  task :daily_job_batch, %i[start_date end_date] => :environment do |_task, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 7.days.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current - 1.day

    puts "Running batch daily statistics job from #{start_date} to #{end_date}..."

    begin
      result = Admin::Analytics::DailyStatisticsJob.perform_batch(start_date, end_date)
      puts 'Batch job completed!'
      puts "Successful: #{result[:success_count]}"
      puts "Failed: #{result[:error_count]}"

      if (result[:error_count]).positive?
        puts "\nErrors:"
        result[:errors].each do |error|
          puts "  #{error[:date]}: #{error[:error]}"
        end
      end
    rescue StandardError => e
      puts "Batch job failed: #{e.message}"
      raise e
    end
  end

  desc '欠損した日次統計データを補完'
  task :backfill_daily_stats, [:days_back] => :environment do |_task, args|
    days_back = args[:days_back] ? args[:days_back].to_i : 30
    puts "Backfilling missing daily statistics data for the last #{days_back} days..."

    begin
      result = Admin::Analytics::DailyStatisticsJob.backfill_missing_data(days_back)

      if (result[:missing_count]).zero?
        puts 'No missing data found!'
      else
        puts "Found #{result[:missing_count]} missing dates"
        puts "Successfully backfilled: #{result[:backfilled].count}"
        puts "Failed to backfill: #{result[:failed].count}"

        if result[:failed].any?
          puts "\nFailed dates:"
          result[:failed].each { |date| puts "  #{date}" }
        end
      end
    rescue StandardError => e
      puts "Backfill failed: #{e.message}"
      raise e
    end
  end

  desc '日次統計Jobをキューに追加（バックグラウンド処理）'
  task :queue_daily_job, [:date] => :environment do |_task, args|
    target_date = args[:date] ? Date.parse(args[:date]) : Date.current - 1.day
    puts "Queueing daily statistics job for #{target_date}..."

    begin
      job = Admin::Analytics::DailyStatisticsJob.perform_later(target_date)
      puts 'Job queued successfully!'
      puts "Job ID: #{job.job_id}" if job.respond_to?(:job_id)
      puts "Target Date: #{target_date}"
      puts "Queue: #{job.queue_name}"
    rescue StandardError => e
      puts "Failed to queue job: #{e.message}"
      raise e
    end
  end
end
