class BackfillPracticeSessionThemeLinks < ActiveRecord::Migration[7.1]
  # マイグレーション内では将来カラム削除・型変更されるアプリのモデルに依存しないよう、
  # このマイグレーション実行時点のテーブル構造だけを見る匿名モデルを使う。
  # rubocop:disable Rails/ApplicationRecord
  class MigrationPracticeSession < ActiveRecord::Base
    self.table_name = 'practice_sessions'
  end

  class MigrationPracticeSessionThemeLink < ActiveRecord::Base
    self.table_name = 'practice_session_theme_links'
  end
  # rubocop:enable Rails/ApplicationRecord

  def up
    MigrationPracticeSession.where.not(improvement_theme_id: nil).find_each do |session|
      MigrationPracticeSessionThemeLink.find_or_create_by!(
        practice_session_id: session.id, improvement_theme_id: session.improvement_theme_id
      )
    end
  end

  def down
    # 複数紐付けがある場合、単一カラムへの書き戻しは情報損失があるため何もしない。
    # ロールバックは本マイグレーションの前段で止める運用とする。
  end
end
