class AddPartialUniqueIndexToPitchersForNullTeam < ActiveRecord::Migration[7.0]
  # PostgreSQL では NULL != NULL のため、(created_by_user_id, team_id, name) の複合 unique index は
  # team_id が NULL のとき同名投手の重複作成を防げない。team_id が NULL のケースに対する
  # 部分インデックスを別途追加し、レースコンディションでも一意性を担保する。
  def change
    add_index :pitchers, %i[created_by_user_id name],
              unique: true,
              where: 'team_id IS NULL',
              name: 'index_pitchers_on_user_name_without_team'
  end
end
