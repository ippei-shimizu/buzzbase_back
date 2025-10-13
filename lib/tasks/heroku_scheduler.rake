# Heroku Scheduler用のラッパータスク
# Heroku Schedulerは「毎日」しか設定できないため、
# 曜日や日付で条件分岐を行う

namespace :heroku do
  desc 'Weekly job - runs only on Monday (for Heroku Scheduler)'
  task weekly: :environment do
    unless Date.current.monday?
      puts "Skipping weekly job: Today is #{Date.current.strftime('%A')}, not Monday"
      next
    end

    puts "Running weekly statistics job for #{Date.current}..."
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

  desc 'Monthly job - runs only on 1st day of month (for Heroku Scheduler)'
  task monthly: :environment do
    unless Date.current.day == 1
      puts "Skipping monthly job: Today is day #{Date.current.day}, not 1st"
      next
    end

    puts "Running monthly statistics job for #{Date.current.strftime('%Y-%m')}..."
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
