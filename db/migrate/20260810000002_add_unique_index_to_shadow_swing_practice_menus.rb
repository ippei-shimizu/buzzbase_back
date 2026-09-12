class AddUniqueIndexToShadowSwingPracticeMenus < ActiveRecord::Migration[7.1]
  MENU_NAME = '素振り'.freeze
  MENU_UNIT = 'count'.freeze
  INDEX_NAME = 'index_practice_menus_on_user_id_and_shadow_swing_name'.freeze
  TARGET_CONDITION = "name = '#{MENU_NAME}' AND unit = '#{MENU_UNIT}'".freeze

  # 素振りメニューは名前で既存行を探して無ければ作るため、初回セッションの同時完了で
  # 同名メニューが重複作成されうる。ユーザーが任意の名前を重複させること自体は許容する仕様なので、
  # 自動生成対象に絞った部分ユニークインデックスで競合を検知できるようにする。
  #
  # 対象は name = '素振り' かつ unit = 'count' のみ。ShadowSwingSession#linked_menu は
  # count 単位のメニューだけを紐付け対象とし、それ以外の単位の同名メニューは
  # 無関係なリソースとして素通りさせるため、制約もマージもその範囲に合わせる。
  def up
    merge_duplicated_menus
    add_index :practice_menus, %i[user_id name], unique: true, where: TARGET_CONDITION, name: INDEX_NAME
  end

  def down
    remove_index :practice_menus, name: INDEX_NAME
  end

  private

  # 制約追加前に既存の重複を最古の1件へ寄せる。参照元を先に付け替えてから重複行を削除する。
  def merge_duplicated_menus
    # 同一 (user_id, input_type, metric) の組み合わせは一意制約があるため、
    # 付け替え前に keeper 側だけでなく敗者行同士の重複も含めてグループ内で1件に絞る。
    # 絞らずに付け替えると、敗者メニューが3件以上あり複数の敗者に同じ組み合わせが
    # またがっているケースで UPDATE 自体が一意制約違反になりうる。
    execute(<<-SQL.squish)
      DELETE FROM insight_combinations
      USING (
        SELECT ic.id,
               ROW_NUMBER() OVER (
                 PARTITION BY ranked.keeper_id, ic.input_type, ic.metric
                 ORDER BY ic.practice_menu_id
               ) AS row_number
        FROM insight_combinations ic
        JOIN (#{ranked_menus_sql}) AS ranked ON ranked.id = ic.practice_menu_id
      ) AS dedup
      WHERE insight_combinations.id = dedup.id AND dedup.row_number > 1
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
      FROM practice_menus WHERE #{TARGET_CONDITION}
    SQL
  end
end
