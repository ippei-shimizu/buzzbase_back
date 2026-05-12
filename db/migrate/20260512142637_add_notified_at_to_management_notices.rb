class AddNotifiedAtToManagementNotices < ActiveRecord::Migration[7.0]
  def change
    add_column :management_notices, :notified_at, :datetime

    # 既存のpublishedレコードに対し、デプロイ後の最初のupdate等で
    # 過去お知らせが誤ってプッシュ送信されることを防ぐためバックフィルする。
    reversible do |dir|
      dir.up do
        ManagementNotice.where(status: ManagementNotice.statuses[:published])
                        .where.not(published_at: nil)
                        .update_all('notified_at = published_at') # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
