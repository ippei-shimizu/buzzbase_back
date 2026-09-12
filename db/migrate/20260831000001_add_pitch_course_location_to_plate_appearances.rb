class AddPitchCourseLocationToPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    # コース図上のタップ位置を正規化座標 (0.0〜1.0) で保存する。hit_location_x/y と同じ流儀。
    # pitch_course (1〜25) はこの座標から導出した値で、集計はそちらを使う。
    change_table :plate_appearances, bulk: true do |t|
      t.decimal :pitch_course_x, precision: 4, scale: 3
      t.decimal :pitch_course_y, precision: 4, scale: 3
    end
  end
end
