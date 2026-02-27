# 開発環境データ作成タスク
# rake dev_data:setup   -- マスターデータ + サンプルデータを一括作成
# rake dev_data:master  -- マスターデータのみ
# rake dev_data:sample  -- サンプルデータのみ（マスターデータが必要）
# rake dev_data:reset   -- DB再作成 + setup

require_relative 'dev_data_creator'
namespace :dev_data do
  desc '開発環境データを一括作成（マスターデータ + サンプルデータ）'
  task setup: :environment do
    Rake::Task['dev_data:master'].invoke
    Rake::Task['dev_data:sample'].invoke
  end

  desc 'マスターデータを作成（Position, Prefecture, BaseballCategory, Admin::User）'
  task master: :environment do
    Rails.logger.debug 'Creating master data...'

    DevDataCreator.create_positions
    DevDataCreator.create_prefectures
    DevDataCreator.create_baseball_categories
    DevDataCreator.create_admin_user

    Rails.logger.debug 'Master data creation completed!'
  end

  desc 'サンプルデータを作成（Users, Teams, GameResults等）— マスターデータが必要'
  task sample: :environment do
    if Position.count.zero?
      Rails.logger.debug 'Position data not found. Please run `rake dev_data:master` first.'
      exit 1
    end

    Rails.logger.debug 'Creating sample data...'

    users = DevDataCreator.create_users
    teams = DevDataCreator.create_teams
    DevDataCreator.create_game_results(users, teams)
    DevDataCreator.create_relationships(users)
    private_users = DevDataCreator.setup_private_accounts(users)
    DevDataCreator.create_pending_follow_requests(users, private_users)
    DevDataCreator.create_follow_notifications
    DevDataCreator.create_groups(users)
    DevDataCreator.create_baseball_notes(users)
    DevDataCreator.print_summary

    Rails.logger.debug 'Sample data creation completed!'
  end

  desc 'DB再作成 + 開発環境データ一括作成'
  task reset: :environment do
    # 他のセッションを切断してからdrop
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
      WHERE pg_stat_activity.datname = current_database()
        AND pid <> pg_backend_pid()
    SQL
    ActiveRecord::Base.connection_pool.disconnect!

    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    Rake::Task['db:migrate'].invoke
    Rake::Task['dev_data:setup'].invoke
  end
end
