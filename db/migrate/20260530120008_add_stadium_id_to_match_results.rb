class AddStadiumIdToMatchResults < ActiveRecord::Migration[7.0]
  def change
    add_reference :match_results, :stadium, foreign_key: true, null: true
  end
end
