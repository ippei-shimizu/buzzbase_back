# anonymize は PII の一括無効化が目的で、意図的に update_all/delete_all（バリデーションスキップ）を使う。
# rubocop:disable Rails/SkipsModelValidations, Metrics/BlockLength
namespace :qa do
  desc '本番由来 DB の PII を匿名化する。本番では絶対に実行しない。'
  task anonymize: :environment do
    raise '本番環境では qa:anonymize を実行できません' if Rails.env.production?

    require 'bcrypt'
    # 全ユーザー共通で使い回す bcrypt ハッシュ（QA 用の固定パスワード）。
    common_password_hash = BCrypt::Password.create('buzzbase-qa-password')

    ActiveRecord::Base.transaction do
      # 最優先: push 通知の誤送信を防ぐため device_token を全削除（2026-05-18 の誤爆事故の再発防止）。
      deleted_tokens = DeviceToken.delete_all
      puts "device_tokens 削除: #{deleted_tokens} 件"

      # users: 1 回の UPDATE で全件を id ベースのダミーに置換し、認証情報（パスワード/トークン）を無効化する。
      # 行ごとの update では Docker 経由の往復が積み上がって極端に遅くなるため、id を参照する一括 SQL にする。
      User.update_all([
                        "email = 'user_' || id || '@example.com', " \
                        "name = 'user_' || id, user_id = 'user_' || id, uid = 'user_' || id, " \
                        'image = NULL, introduction = NULL, positions = NULL, ' \
                        'encrypted_password = ?, ' \
                        'reset_password_token = NULL, confirmation_token = NULL, ' \
                        'unconfirmed_email = NULL, suspended_reason = NULL, tokens = NULL',
                        common_password_hash.to_s
                      ])
      puts "users 匿名化: #{User.count} 件"

      Admin::User.update_all(["name = 'admin', email = 'admin_' || id || '@example.com', password_digest = ?", common_password_hash.to_s])
      puts "admin_users 匿名化: #{Admin::User.count} 件"

      # 自由記述のメモ・タイトルは一律 NULL。
      # game-stats migration の前後どちらでも動くよう、テーブル/カラムの存在を確認してから更新する。
      MatchResult.update_all(memo: nil) if qa_column?(MatchResult, :memo)
      PlateAppearance.update_all(self_analysis_memo: nil, opponent_memo: nil) if qa_column?(PlateAppearance, :self_analysis_memo)
      Pitcher.update_all(memo: nil) if qa_table?('pitchers')
      BaseballNote.update_all(title: nil, memo: nil)

      Group.update_all("name = 'group_' || id")
      Group.update_all(icon: nil) if qa_column?(Group, :icon)
      Group.update_all(description: nil) if qa_column?(Group, :description)

      # 招待コードは varchar(8) かつユニーク制約あり。id の16進ゼロ埋めで 8 文字に収めつつ一意性を担保する。
      GroupInviteLink.update_all("code = lpad(to_hex(id), 8, '0')")

      puts '匿名化完了'
    end
  end

  desc 'マスキング済み DB に migration を適用し、前後で既存集計値・キー値が壊れないか検証する。'
  task rehearse_migration: :environment do
    raise '本番環境では qa:rehearse_migration を実行できません' if Rails.env.production?
    raise 'マスキングされていません。先に qa:anonymize を実行してください' unless qa_anonymized?

    before_snapshot = qa_snapshot
    puts "migration 前スナップショット: batting_averages #{before_snapshot[:batting_averages].size} 件 / " \
         "plate_appearances #{before_snapshot[:plate_appearance_keys].size} 件"

    puts 'rails db:migrate 実行中...'
    Rake::Task['db:migrate'].invoke

    # migration 後はスキーマキャッシュとカラム情報を破棄してから再取得する。
    ActiveRecord::Base.connection.schema_cache.clear!
    [BattingAverage, PlateAppearance].each(&:reset_column_information)
    after_snapshot = qa_snapshot

    diffs = qa_compare(before_snapshot, after_snapshot)
    if diffs.empty?
      puts '✓ migration 前後で既存の集計値・キー値に差分なし'
    else
      puts '✗ 差分を検出（migration が既存データを破壊している可能性）:'
      diffs.first(50).each { |diff| puts "  #{diff}" }
      puts "  ...（他 #{diffs.size - 50} 件）" if diffs.size > 50
      abort "リハーサル失敗: 差分 #{diffs.size} 件"
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations, Metrics/BlockLength

# device_tokens が空で、全ユーザーの email が匿名化済みかでマスキング済みと判定する。
def qa_anonymized?
  DeviceToken.count.zero? && User.where.not("email LIKE '%@example.com'").none?
end

def qa_table?(name)
  ActiveRecord::Base.connection.table_exists?(name)
end

def qa_column?(model, column)
  model.column_names.include?(column.to_s)
end

# migration の前後比較に使う、既存レコードの集計値とキー値のスナップショットを取る。
def qa_snapshot
  {
    batting_averages: BattingAverage.order(:id)
                                    .pluck(:id, :hit, :times_at_bat, :total_bases)
                                    .to_h { |id, *values| [id, values] },
    plate_appearance_keys: PlateAppearance.order(:id)
                                          .pluck(:id, :hit_direction_id, :plate_result_id, :batting_position_id)
                                          .to_h { |id, *values| [id, values] }
  }
end

# 2 つのスナップショットを突き合わせ、変化した id の差分リストを返す。
def qa_compare(before, after)
  diffs = []
  before.each_key do |table|
    before_rows = before[table]
    after_rows = after[table]
    (before_rows.keys | after_rows.keys).each do |id|
      next if before_rows[id] == after_rows[id]

      diffs << "#{table} id=#{id}: #{before_rows[id].inspect} -> #{after_rows[id].inspect}"
    end
  end
  diffs
end
