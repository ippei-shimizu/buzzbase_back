class AddHomeRunTypeToPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    add_column :plate_appearances, :home_run_type, :integer
    # home_run_type は本塁打 (plate_result_id=10) のときだけ意味を持ち、それ以外は NULL。
    # 本塁打以外は全件 NULL になるため単純インデックスでは選択性が極端に低い。
    # swing_type と同じく部分インデックスにして本塁打の内訳集計でのみ実利を得る。
    add_index :plate_appearances, :home_run_type, where: 'home_run_type IS NOT NULL'
  end
end
