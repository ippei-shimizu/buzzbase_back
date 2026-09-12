class CreateVelocityZones < ActiveRecord::Migration[7.0]
  def up
    create_table :velocity_zones do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :velocity_zones, :name, unique: true, name: 'index_velocity_zones_on_name'
    add_index :velocity_zones, :display_order, name: 'index_velocity_zones_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'velocity_zones', file: 'velocity_zones.yml')
  end

  def down
    drop_table :velocity_zones
  end
end
