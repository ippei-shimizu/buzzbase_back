# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Rails.envに応じて環境を設定
set :environment, ENV['RAILS_ENV'] || :development
set :output, "#{path}/log/cron.log"

# 日次統計データ収集（毎日午前6時に前日分を集計）
every 1.day, at: '6:00 am' do
  rake 'analytics:daily_job'
end

# 週次統計データ収集（毎週月曜日午前7時）
every :monday, at: '7:00 am' do
  rake 'analytics:calculate_weekly'
end

# 月次統計データ収集（毎月1日午前8時）
every '0 8 1 * *' do
  rake 'analytics:calculate_monthly'
end

# データ整合性チェック・バックフィル（毎日午前10時）
every 1.day, at: '10:00 am' do
  rake 'analytics:backfill_daily_stats[7]'
end
