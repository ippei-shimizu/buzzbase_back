namespace :pro do
  desc 'トライアル終了 3 日前のリマインダーを送信（Heroku Scheduler から起動）'
  task trial_expiring_reminder: :environment do
    TrialExpiringReminderJob.new.perform
  end

  desc 'Pro 期間終了 3 日前のリマインダーを送信（Heroku Scheduler から起動）'
  task pro_expiring_reminder: :environment do
    ProExpiringReminderJob.new.perform
  end
end
