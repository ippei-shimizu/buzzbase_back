class AddColumnsToPlateAppearances < ActiveRecord::Migration[7.0]
  def change
    change_table :plate_appearances, bulk: true do |t|
      t.integer :out_type
      t.integer :hit_type
      t.integer :rbi
      t.integer :run_scored
      t.integer :stolen_bases
      t.integer :caught_stealing

      t.integer :final_balls
      t.integer :final_strikes
      t.integer :final_outs
      t.boolean :first_pitch_swing
      t.integer :runners_state
      t.integer :inning

      t.references :contact_quality, foreign_key: true, null: true
      t.references :timing, foreign_key: true, null: true
      t.references :pitch_type, foreign_key: true, null: true
      t.references :hit_depth, foreign_key: true, null: true

      t.text :self_analysis_memo
      t.text :opponent_memo

      t.decimal :hit_location_x, precision: 4, scale: 3
      t.decimal :hit_location_y, precision: 4, scale: 3
    end
  end
end
