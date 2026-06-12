class DropHitDepths < ActiveRecord::Migration[7.1]
  def up
    drop_table :hit_depths
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
