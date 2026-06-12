class DropHitDirections < ActiveRecord::Migration[7.1]
  def up
    # plate_appearances.hit_direction_id は素の integer 列で FK 制約は張られていないが、
    # 過去のスキーマ状態によっては存在する可能性があるため防御的に確認する。
    remove_foreign_key :plate_appearances, :hit_directions if foreign_key_exists?(:plate_appearances, :hit_directions)
    drop_table :hit_directions
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
