class RemoveHitDepthFromPlateAppearances < ActiveRecord::Migration[7.1]
  def up
    remove_reference :plate_appearances, :hit_depth, foreign_key: true, index: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
