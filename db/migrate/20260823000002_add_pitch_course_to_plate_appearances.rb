class AddPitchCourseToPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    # 捕手目線の 5x5 グリッド (1〜25)。NULL = 未記録。
    add_column :plate_appearances, :pitch_course, :integer
    # コース未入力の PA が大半を占めるため、swing_type と同様に
    # NOT NULL に絞った部分インデックスにして集計クエリでのみ実利を得る。
    add_index :plate_appearances, :pitch_course, where: 'pitch_course IS NOT NULL'
  end
end
