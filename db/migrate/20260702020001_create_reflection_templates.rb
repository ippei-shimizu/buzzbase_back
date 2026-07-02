class CreateReflectionTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :reflection_templates do |t|
      # user_id が nil のものは運営提供プリセット（全ユーザーが利用可）。
      t.references :user, null: true, foreign_key: true
      t.string :title, null: false
      t.jsonb :questions, null: false, default: []
      t.boolean :is_preset, null: false, default: false
      t.boolean :is_default, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :reflection_templates, :is_preset
  end
end
