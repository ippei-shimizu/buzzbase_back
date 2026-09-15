class AddHomeRunTypeToPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    add_column :plate_appearances, :home_run_type, :integer
    # home_run_type は本塁打 (plate_result_id=10) のときだけ意味を持ち、それ以外は NULL。
    # 内訳集計は必ず user_id と組で引くため user_id を先頭に置く。home_run_type 単独では
    # 部分インデックスで NULL を除いた後の distinct が 2 値しか無く選択性が出ない。
    add_index :plate_appearances, %i[user_id home_run_type], where: 'home_run_type IS NOT NULL'
  end
end
