class AddUniqueIndexOnGameResultId < ActiveRecord::Migration[7.0]
  def up
    # 重複データを削除（最新のレコードを残す）
    execute <<-SQL.squish
      DELETE FROM match_results
      WHERE id NOT IN (
        SELECT MAX(id) FROM match_results
        WHERE game_result_id IS NOT NULL
        GROUP BY game_result_id
      )
      AND game_result_id IS NOT NULL
    SQL

    execute <<-SQL.squish
      DELETE FROM batting_averages
      WHERE id NOT IN (
        SELECT MAX(id) FROM batting_averages
        GROUP BY game_result_id
      )
    SQL

    add_index :match_results, :game_result_id, unique: true, where: 'game_result_id IS NOT NULL',
                                                name: 'index_match_results_on_game_result_id_unique'

    remove_index :batting_averages, name: 'index_batting_averages_on_game_result_id'
    add_index :batting_averages, :game_result_id, unique: true,
                                                  name: 'index_batting_averages_on_game_result_id'
  end

  def down
    remove_index :match_results, name: 'index_match_results_on_game_result_id_unique'
    remove_index :batting_averages, name: 'index_batting_averages_on_game_result_id'
    add_index :batting_averages, :game_result_id, name: 'index_batting_averages_on_game_result_id'
  end
end
