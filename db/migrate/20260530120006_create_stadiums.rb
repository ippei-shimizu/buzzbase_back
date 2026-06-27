class CreateStadiums < ActiveRecord::Migration[7.0]
  def change
    create_table :stadiums do |t|
      t.string :name, null: false
      t.references :prefecture, null: true, foreign_key: true
      t.references :created_by_user, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :stadiums, :name, name: 'index_stadiums_on_name'
  end
end
