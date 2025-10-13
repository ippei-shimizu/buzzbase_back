# Heroku Scheduler用のラッパータスク
# Heroku Schedulerは「毎日」しか設定できないため、
# 曜日や日付で条件分岐を行う
#
# 注意: Heroku SchedulerはUTCベースで動作するため、
# JST（日本時間）での判定が必要な場合は Time.zone を使用する

namespace :heroku do
  desc 'Weekly job - runs only on Monday JST (for Heroku Scheduler)'
  task weekly: :environment do
    # 日本時間での曜日判定
    jst_time = Time.current.in_time_zone('Tokyo')
    jst_date = jst_time.to_date

    unless jst_date.monday?
      puts "Skipping weekly job: Today (JST) is #{jst_date.strftime('%A %Y-%m-%d')}, not Monday"
      next
    end

    puts "Running weekly statistics job for #{jst_date}..."
    begin
      Rake::Task['analytics:calculate_weekly'].invoke
      puts 'Weekly job completed successfully!'
    rescue StandardError => e
      puts "Weekly job failed: #{e.message}"
      Rails.logger.error("Heroku weekly job failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise e
    end
  end

  desc 'Monthly job - runs only on 1st day of month JST (for Heroku Scheduler)'
  task monthly: :environment do
    # 日本時間での日付判定
    jst_time = Time.current.in_time_zone('Tokyo')
    jst_date = jst_time.to_date

    unless jst_date.day == 1
      puts "Skipping monthly job: Today (JST) is #{jst_date.strftime('%Y-%m-%d')} (day #{jst_date.day}), not 1st"
      next
    end

    puts "Running monthly statistics job for #{jst_date.strftime('%Y-%m')}..."
    begin
      Rake::Task['analytics:calculate_monthly'].invoke
      puts 'Monthly job completed successfully!'
    rescue StandardError => e
      puts "Monthly job failed: #{e.message}"
      Rails.logger.error("Heroku monthly job failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise e
    end
  end
end
