class CreateTimings < ActiveRecord::Migration[7.0]
  def up
    create_table :timings do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :timings, :name, unique: true, name: 'index_timings_on_name'
    add_index :timings, :display_order, name: 'index_timings_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'timings', file: 'timings.yml')
  end

  def down
    drop_table :timings
  end
end
