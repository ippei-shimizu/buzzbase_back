class CreateNoteTags < ActiveRecord::Migration[7.1]
  def change
    create_table :note_tags do |t|
      # user_id が nil のものは運営提供プリセット（全員が参照）。
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.boolean :is_preset, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :note_tags, %i[user_id name], unique: true
  end
end
