class CreatePlateResults < ActiveRecord::Migration[7.0]
  def up
    create_table :plate_results do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.boolean :hit_direction_required, null: false, default: false
      t.boolean :counted_in_at_bats, null: false, default: false
      t.timestamps
    end
    add_index :plate_results, :name, unique: true, name: 'index_plate_results_on_name'
    add_index :plate_results, :display_order, name: 'index_plate_results_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'plate_results', file: 'plate_results.yml')
  end

  def down
    drop_table :plate_results
  end
end
