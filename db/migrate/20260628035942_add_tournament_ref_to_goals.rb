class AddTournamentRefToGoals < ActiveRecord::Migration[7.1]
  def change
    add_column :goals, :tournament_id, :bigint
    add_foreign_key :goals, :tournaments, on_delete: :nullify
  end
end
