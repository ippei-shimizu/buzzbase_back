class AddIndexToUsersTeamId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :users, :team_id, algorithm: :concurrently
  end
end
