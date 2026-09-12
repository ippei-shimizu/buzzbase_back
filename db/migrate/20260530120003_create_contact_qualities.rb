class CreateContactQualities < ActiveRecord::Migration[7.0]
  def up
    create_table :contact_qualities do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :contact_qualities, :name, unique: true, name: 'index_contact_qualities_on_name'
    add_index :contact_qualities, :display_order, name: 'index_contact_qualities_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'contact_qualities', file: 'contact_qualities.yml')
  end

  def down
    drop_table :contact_qualities
  end
end
