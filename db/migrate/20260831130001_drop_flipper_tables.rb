class DropFlipperTables < ActiveRecord::Migration[7.1]
  # Flipper 機構ごと撤去したため永続化テーブルも削除する。
  def up
    drop_table :flipper_gates, if_exists: true
    drop_table :flipper_features, if_exists: true
  end

  def down
    create_table :flipper_features do |t|
      t.string :key, null: false
      t.timestamps
      t.index :key, unique: true
    end

    create_table :flipper_gates do |t|
      t.string :feature_key, null: false
      t.string :key, null: false
      t.text :value
      t.timestamps
      t.index %i[feature_key key value], unique: true
    end
  end
end
