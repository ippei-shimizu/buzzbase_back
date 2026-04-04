class AddHitDirectionIdToPlateAppearances < ActiveRecord::Migration[7.0]
  def change
    add_column :plate_appearances, :hit_direction_id, :integer
  end
end
