class AddUniqueIndexToShadowSwingPracticeMenus < ActiveRecord::Migration[7.1]
  MENU_NAME = '素振り'.freeze
  INDEX_NAME = 'index_practice_menus_on_user_id_and_shadow_swing_name'.freeze

  # 素振りメニューは名前で既存行を探して無ければ作るため、初回セッションの同時完了で
  # 同名メニューが重複作成されうる。ユーザーが任意の名前を重複させること自体は許容する仕様なので、
  # 自動生成対象の '素振り' に限定した部分ユニークインデックスで競合を検知できるようにする。
  def up
    merge_duplicated_menus
    add_index :practice_menus, %i[user_id name], unique: true, where: "name = '#{MENU_NAME}'", name: INDEX_NAME
  end

  def down
    remove_index :practice_menus, name: INDEX_NAME
  end

  private

  # 制約追加前に既存の重複を最古の1件へ寄せる。参照元を先に付け替えてから重複行を削除する。
  def merge_duplicated_menus
    # 同一 (user_id, input_type, metric) の組み合わせは一意制約があるため、
    # 付け替えると keeper 側と衝突する敗者側の行だけ先に落とす。
    execute(<<-SQL.squish)
      DELETE FROM insight_combinations
      USING (#{ranked_menus_sql}) AS ranked
      WHERE insight_combinations.practice_menu_id = ranked.id
        AND ranked.id <> ranked.keeper_id
        AND EXISTS (
          SELECT 1 FROM insight_combinations keeper_row
          WHERE keeper_row.user_id = insight_combinations.user_id
            AND keeper_row.input_type = insight_combinations.input_type
            AND keeper_row.metric = insight_combinations.metric
            AND keeper_row.practice_menu_id = ranked.keeper_id
        )
    SQL

    %w[practice_logs goals menu_set_items schedule_menus insight_combinations].each do |table|
      execute(<<-SQL.squish)
        UPDATE #{table} SET practice_menu_id = ranked.keeper_id
        FROM (#{ranked_menus_sql}) AS ranked
        WHERE #{table}.practice_menu_id = ranked.id AND ranked.id <> ranked.keeper_id
      SQL
    end

    execute(<<-SQL.squish)
      DELETE FROM practice_menus
      USING (#{ranked_menus_sql}) AS ranked
      WHERE practice_menus.id = ranked.id AND ranked.id <> ranked.keeper_id
    SQL
  end

  def ranked_menus_sql
    <<-SQL.squish
      SELECT id, FIRST_VALUE(id) OVER (PARTITION BY user_id ORDER BY id) AS keeper_id
      FROM practice_menus WHERE name = '#{MENU_NAME}'
    SQL
  end
end
