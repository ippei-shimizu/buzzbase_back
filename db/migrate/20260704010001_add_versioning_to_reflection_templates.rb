class AddVersioningToReflectionTemplates < ActiveRecord::Migration[7.1]
  def change
    # 編集時は原本を更新せず新バージョンを作る運用にするための列。
    # archived_at: 旧版を一覧から隠す（過去ノートの reflection_template_id 参照は保持する）。
    # origin_template_id: どのテンプレ（特に共有プリセット）から派生したかを辿り、
    #   本人がコピーを持つプリセットを一覧から隠すのに使う。
    change_table :reflection_templates, bulk: true do |t|
      t.datetime :archived_at, null: true
      t.bigint :origin_template_id, null: true
      t.index :archived_at
      t.index :origin_template_id
    end
  end
end
