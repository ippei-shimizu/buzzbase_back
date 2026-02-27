class CreateGroupRankingSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :group_ranking_snapshots do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :stat_type, null: false
      t.integer :rank, null: false
      t.decimal :value, precision: 10, scale: 3, null: false
      t.date :snapshot_date, null: false

      t.timestamps
    end

    add_index :group_ranking_snapshots,
              %i[group_id user_id stat_type snapshot_date],
              unique: true,
              name: 'idx_group_ranking_snapshots_unique'
    add_index :group_ranking_snapshots, :snapshot_date
  end
end
