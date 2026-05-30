class CreateHitDepths < ActiveRecord::Migration[7.0]
  def up
    create_table :hit_depths do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :hit_depths, :name, unique: true, name: 'index_hit_depths_on_name'
    add_index :hit_depths, :display_order, name: 'index_hit_depths_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'hit_depths', file: 'hit_depths.yml')
  end

  def down
    drop_table :hit_depths
  end
end
