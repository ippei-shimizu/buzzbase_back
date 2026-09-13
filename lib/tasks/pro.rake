namespace :pro do
  desc 'トライアル終了 3 日前のリマインダーを送信（Heroku Scheduler から起動）'
  task trial_expiring_reminder: :environment do
    TrialExpiringReminderJob.perform_now
  end

  desc 'Pro 期間終了 3 日前のリマインダーを送信（Heroku Scheduler から起動）'
  task pro_expiring_reminder: :environment do
    ProExpiringReminderJob.perform_now
  end

  desc '内部利用（録画・審査・開発）の手動 Pro 付与に internal_grant フラグを立てる。user_id は users.id'
  task :mark_internal, %i[user_id reason] => :environment do |_task, args|
    subscription = pro_find_subscription!(args[:user_id])
    reason = args[:reason].presence || raise(ArgumentError, 'reason は必須です（例: 録画用 / 審査用 / 開発者本人）')

    subscription.mark_internal_grant!(reason)
    puts "internal_grant を設定しました: #{pro_describe(subscription)}"
  end

  desc 'internal_grant フラグを外す（手動付与ユーザーが実課金に切り替わったとき）。user_id は users.id'
  task :unmark_internal, [:user_id] => :environment do |_task, args|
    subscription = pro_find_subscription!(args[:user_id])

    subscription.unmark_internal_grant!
    puts "internal_grant を解除しました: #{pro_describe(subscription)}"
  end

  desc '手動付与した Pro を free に戻す（録画・審査が終わったアカウント向け）。user_id は users.id'
  task :revoke_internal_grant, [:user_id] => :environment do |_task, args|
    subscription = pro_find_subscription!(args[:user_id])

    subscription.revoke_internal_grant!
    puts "手動付与を無効化しました: #{pro_describe(subscription)}"
  end

  desc 'free 以外の Subscription を実課金 / 内部付与に分けて一覧表示する（課金分析の前提確認用）'
  task audit: :environment do
    pro_subscriptions = Subscription.includes(:user).where.not(status: 'free').order(:id)
    billable = pro_subscriptions.billable
    internal_grants = pro_subscriptions.internal_grants

    puts "実課金（分析対象）: #{billable.size} 件"
    billable.each { |subscription| puts "  #{pro_describe(subscription)}" }

    puts "内部付与（分析から除外）: #{internal_grants.size} 件"
    internal_grants.each { |subscription| puts "  #{pro_describe(subscription)}" }

    suspected_manual_grants = billable.select { |subscription| subscription.started_at.nil? }
    next if suspected_manual_grants.empty?

    puts '要確認: started_at が null なのに internal_grant が付いていないレコードがあります。' \
         '手動付与なら pro:mark_internal でフラグを立ててください。'
    suspected_manual_grants.each { |subscription| puts "  #{pro_describe(subscription)}" }
  end
end

# users.id から Subscription を引く。未作成のユーザーはフラグの立てようがないため例外にする。
def pro_find_subscription!(user_id)
  raise ArgumentError, 'user_id（users.id）を指定してください' if user_id.blank?

  user = User.find(user_id)
  user.subscription || raise(ActiveRecord::RecordNotFound, "user #{user_id} に subscription がありません")
end

def pro_describe(subscription)
  [
    "user_id=#{subscription.user_id}",
    "handle=#{subscription.user&.user_id}",
    "status=#{subscription.status}",
    "plan_type=#{subscription.plan_type || '-'}",
    "platform=#{subscription.platform || '-'}",
    "started_at=#{subscription.started_at&.iso8601 || '-'}",
    "internal_grant=#{subscription.internal_grant}",
    "reason=#{subscription.internal_grant_reason || '-'}"
  ].join(' ')
end
