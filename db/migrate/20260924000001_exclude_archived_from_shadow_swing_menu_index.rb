class ExcludeArchivedFromShadowSwingMenuIndex < ActiveRecord::Migration[7.1]
  INDEX_NAME = 'index_practice_menus_on_user_id_and_shadow_swing_name'.freeze
  OLD_CONDITION = "name = '素振り' AND unit = 'count'".freeze
  NEW_CONDITION = "#{OLD_CONDITION} AND archived = false".freeze

  # メニュー削除は論理削除（archived）なので、archived を含めたままだと
  # 一度削除した素振りメニューをユーザーが二度と作り直せなくなる。
  # 制約対象を active な行だけに絞る。
  #
  # DDL トランザクション内で張り替えるため制約が消える瞬間は他セッションから見えない。
  # インデックス構築中は practice_menus が ACCESS EXCLUSIVE ロックで止まるが、
  # 行数が小さく一瞬で終わるため許容する。大きくなったら concurrently 化が必要。
  def up
    remove_index :practice_menus, name: INDEX_NAME
    add_index :practice_menus, %i[user_id name], unique: true, where: NEW_CONDITION, name: INDEX_NAME
  end

  # up 適用後は「削除済みの素振りメニュー + 新しい素振りメニュー」が同一ユーザーに
  # 共存しうる（それがこの変更の目的）。旧条件は archived を含むため、その状態では
  # インデックスを張り直せない。戻すには重複行の扱いを人が決める必要がある。
  def down
    raise ActiveRecord::IrreversibleMigration,
          "#{INDEX_NAME} は archived 込みの一意制約に自動では戻せません。" \
          '重複する素振りメニューを整理してから、旧条件でインデックスを張り直してください。'
  end
end
