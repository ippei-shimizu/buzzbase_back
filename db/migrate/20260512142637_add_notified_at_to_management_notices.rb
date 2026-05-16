class AddNotifiedAtToManagementNotices < ActiveRecord::Migration[7.0]
  def change
    add_column :management_notices, :notified_at, :datetime

    # 既存のpublishedレコードに対し、デプロイ後の最初のupdate等で
    # 過去お知らせが誤ってプッシュ送信されることを防ぐためバックフィルする。
    # マイグレーション内ではモデルクラスを直接参照せず、生SQLでstatus=1（published）を指定する。
    # （モデルにバリデーション/コールバックが追加された際にゼロからのdb:migrateが壊れることを防ぐため）
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE management_notices
          SET notified_at = published_at
          WHERE status = 1
            AND published_at IS NOT NULL
        SQL
      end
    end
  end
end
