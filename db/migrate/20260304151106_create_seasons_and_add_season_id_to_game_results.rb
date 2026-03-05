class CreateSeasonsAndAddSeasonIdToGameResults < ActiveRecord::Migration[7.0]
  def change
    create_table :seasons do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :seasons, [:user_id, :name], unique: true
    add_reference :game_results, :season, null: true, foreign_key: { on_delete: :nullify }
  end
end
