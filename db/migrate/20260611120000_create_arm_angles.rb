class CreateArmAngles < ActiveRecord::Migration[7.0]
  def up
    create_table :arm_angles do |t|
      t.string :name, null: false
      t.integer :display_order, null: false
      t.timestamps
    end
    add_index :arm_angles, :name, unique: true, name: 'index_arm_angles_on_name'
    add_index :arm_angles, :display_order, name: 'index_arm_angles_on_display_order'

    MasterData::Seeder.from_yaml(connection, table: 'arm_angles', file: 'arm_angles.yml')
  end

  def down
    drop_table :arm_angles
  end
end
