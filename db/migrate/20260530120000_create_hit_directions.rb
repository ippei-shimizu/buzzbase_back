class CreateHitDirections < ActiveRecord::Migration[7.0]
  def up
    create_table :hit_directions do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.jsonb :zone_polygon
      t.timestamps
    end
    add_index :hit_directions, :name, unique: true, name: 'index_hit_directions_on_name'
    add_index :hit_directions, :display_order, name: 'index_hit_directions_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'hit_directions', file: 'hit_directions.yml')
  end

  def down
    drop_table :hit_directions
  end
end
