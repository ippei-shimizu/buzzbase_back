class CreatePitcherStyles < ActiveRecord::Migration[7.0]
  def up
    create_table :pitcher_styles do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :pitcher_styles, :name, unique: true, name: 'index_pitcher_styles_on_name'
    add_index :pitcher_styles, :display_order, name: 'index_pitcher_styles_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'pitcher_styles', file: 'pitcher_styles.yml')
  end

  def down
    drop_table :pitcher_styles
  end
end
