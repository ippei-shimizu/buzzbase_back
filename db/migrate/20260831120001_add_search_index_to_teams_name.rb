class AddSearchIndexToTeamsName < ActiveRecord::Migration[7.1]
  # チーム名の ILIKE 部分一致検索が毎回 Seq Scan にならないよう trigram GIN index を張る。
  # 前方一致だけでなく中間一致もインデックスを使えるようにするため b-tree ではなく pg_trgm を使う。
  # pg_trgm は Heroku Postgres で追加設定なしに有効化できる標準拡張。
  def up
    enable_extension 'pg_trgm'
    add_index :teams, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_teams_on_name_trgm'
  end

  # pg_trgm はデータベース全体で共有される拡張のため、rollback では無効化しない。
  def down
    remove_index :teams, name: 'index_teams_on_name_trgm'
  end
end
