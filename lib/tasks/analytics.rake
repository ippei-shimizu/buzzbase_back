namespace :analytics do
  desc 'Calculate daily statistics for a specific date'
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

  desc 'Calculate daily statistics for a date range'
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

  desc 'Clean up old user activities (older than 90 days)'
  task cleanup_activities: :environment do
    cutoff_date = 90.days.ago

    puts "Cleaning up user activities older than #{cutoff_date}..."

    begin
      # 古いアクティビティの削除は不要（user_activitiesテーブルを使用しないため）
      puts 'Activity cleanup not required - using direct table aggregation'
    rescue StandardError => e
      puts "Error during cleanup: #{e.message}"
      raise e
    end
  end

  desc 'Calculate weekly statistics for a specific date'
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

  desc 'Calculate monthly statistics for a specific date'
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

  desc 'Calculate weekly statistics for a date range'
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

  desc 'Calculate monthly statistics for a date range'
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

  desc 'Generate analytics report for the last 30 days'
  task generate_report: :environment do
    puts 'Generating analytics report for the last 30 days...'

    end_date = Date.current
    start_date = 30.days.ago.to_date

    stats = Admin::DailyStatistic.by_date_range(start_date, end_date)

    puts "\n=== BuzzBase Analytics Report (#{start_date} to #{end_date}) ==="
    puts "Total Users: #{stats.last&.total_users || 0}"
    puts "Average Daily Active Users: #{stats.average(:active_users).to_f.round(2)}"
    puts "Total New Users: #{stats.sum(:new_users)}"
    puts "Total Games: #{stats.sum(:total_games)}"
    puts "Total Batting Records: #{stats.sum(:total_batting_records)}"
    puts "Total Pitching Records: #{stats.sum(:total_pitching_records)}"
    puts "Total Posts: #{stats.sum(:total_posts)}"

    puts "\nGrowth Rates (7-day comparison):"
    puts "  Users: #{Admin::DailyStatistic.growth_rate(:total_users, 7)}%"
    puts "  Active Users: #{Admin::DailyStatistic.growth_rate(:active_users, 7)}%"
    puts "  Games: #{Admin::DailyStatistic.growth_rate(:total_games, 7)}%"
    puts "  Batting Records: #{Admin::DailyStatistic.growth_rate(:total_batting_records, 7)}%"
    puts "  Pitching Records: #{Admin::DailyStatistic.growth_rate(:total_pitching_records, 7)}%"
    puts "  Posts: #{Admin::DailyStatistic.growth_rate(:total_posts, 7)}%"

    puts "\nRetention Rates (7-day cohort):"
    cohort_date = 7.days.ago.to_date
    [1, 3, 7].each do |period|
      rate = Admin::DailyStatistic.retention_rate(cohort_date, period)
      puts "  #{period} day: #{rate}%"
    end

    puts "\nTop Activities:"
    activity_summary = {
      games: GameResult.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count,
      batting_records: BattingAverage.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count,
      pitching_records: PitchingResult.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count
    }
    activity_summary.sort_by { |_, count| -count }.first(5).each do |activity, count|
      puts "  #{activity}: #{count}"
    end

    puts "\n=== End of Report ==="
  end

  desc 'Create initial admin user'
  task create_admin: :environment do
    email = ENV['ADMIN_EMAIL'] || 'admin@buzzbase.com'
    password = ENV['ADMIN_PASSWORD'] || SecureRandom.hex(8)
    name = ENV['ADMIN_NAME'] || 'System Administrator'

    begin
      admin = Admin::User.create!(
        email:,
        name:,
        password:,
        password_confirmation: password,
        role: :super_admin,
        permissions_list: %w[analytics manage_users manage_admins]
      )

      puts 'Admin user created successfully!'
      puts "Email: #{admin.email}"
      puts "Password: #{password}"
      puts "Role: #{admin.role}"
      puts "\nPlease save these credentials securely and change the password after first login."
    rescue ActiveRecord::RecordInvalid => e
      puts "Error creating admin user: #{e.record.errors.full_messages.join(', ')}"
    rescue StandardError => e
      puts "Unexpected error: #{e.message}"
      raise e
    end
  end
end
