class AddPitcherColumnsToPlateAppearances < ActiveRecord::Migration[7.0]
  def change
    change_table :plate_appearances, bulk: true do |t|
      t.references :pitcher, foreign_key: true, null: true
      t.references :appearance_situation, foreign_key: true, null: true
    end
  end
end
