class RemoveHitDepthFromPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    remove_reference :plate_appearances, :hit_depth, foreign_key: true, index: true
  end
end
