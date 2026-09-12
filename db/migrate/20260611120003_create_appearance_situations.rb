class CreateAppearanceSituations < ActiveRecord::Migration[7.0]
  def up
    create_table :appearance_situations do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :appearance_situations, :name, unique: true, name: 'index_appearance_situations_on_name'
    add_index :appearance_situations, :display_order, name: 'index_appearance_situations_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'appearance_situations', file: 'appearance_situations.yml')
  end

  def down
    drop_table :appearance_situations
  end
end
