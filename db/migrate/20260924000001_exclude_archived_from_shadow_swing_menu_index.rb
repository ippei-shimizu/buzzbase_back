class ExcludeArchivedFromShadowSwingMenuIndex < ActiveRecord::Migration[7.1]
  INDEX_NAME = 'index_practice_menus_on_user_id_and_shadow_swing_name'.freeze
  OLD_CONDITION = "name = '素振り' AND unit = 'count'".freeze
  NEW_CONDITION = "#{OLD_CONDITION} AND archived = false".freeze

  # メニュー削除は論理削除（archived）なので、archived を含めたままだと
  # 一度削除した素振りメニューをユーザーが二度と作り直せなくなる。
  # 制約対象を active な行だけに絞る。
  def up
    remove_index :practice_menus, name: INDEX_NAME
    add_index :practice_menus, %i[user_id name], unique: true, where: NEW_CONDITION, name: INDEX_NAME
  end

  def down
    remove_index :practice_menus, name: INDEX_NAME
    add_index :practice_menus, %i[user_id name], unique: true, where: OLD_CONDITION, name: INDEX_NAME
  end
end
