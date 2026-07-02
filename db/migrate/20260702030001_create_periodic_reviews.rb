class CreatePeriodicReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :periodic_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.string :period_type, null: false # 'weekly' / 'monthly'
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.jsonb :summary, null: false, default: {}
      t.boolean :read, null: false, default: false
      t.timestamps
    end

    add_index :periodic_reviews, %i[user_id period_type period_start], unique: true
  end
end
