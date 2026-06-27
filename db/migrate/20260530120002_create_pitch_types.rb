class CreatePitchTypes < ActiveRecord::Migration[7.0]
  def up
    create_table :pitch_types do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :pitch_types, :name, unique: true, name: 'index_pitch_types_on_name'
    add_index :pitch_types, :display_order, name: 'index_pitch_types_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'pitch_types', file: 'pitch_types.yml')
  end

  def down
    drop_table :pitch_types
  end
end
