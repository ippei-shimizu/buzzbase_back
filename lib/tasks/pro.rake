namespace :pro do
  desc 'トライアル終了 3 日前のリマインダーを送信（Heroku Scheduler から起動）'
  task trial_expiring_reminder: :environment do
    TrialExpiringReminderJob.perform_now
  end

  desc 'Pro 期間終了 3 日前のリマインダーを送信（Heroku Scheduler から起動）'
  task pro_expiring_reminder: :environment do
    ProExpiringReminderJob.perform_now
  end

  desc '指定メールアドレスのユーザーを admin にする(development 限定、強制 Pro モード用)'
  task :make_admin, [:email] => :environment do |_task, args|
    raise 'production では実行できません' if Rails.env.production?
    raise 'Usage: rails pro:make_admin[email@example.com]' if args.email.blank?

    user = User.find_by!(email: args.email)
    user.update!(is_admin: true)
    puts "#{user.email} を admin にしました（development 環境で強制 Pro モードが有効になります）"
  end
end
