class AddUniqueIndexOnGameResultId < ActiveRecord::Migration[7.0]
  def up
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
