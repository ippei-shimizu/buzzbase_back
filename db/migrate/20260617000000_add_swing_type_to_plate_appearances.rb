class AddSwingTypeToPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    add_column :plate_appearances, :swing_type, :integer
    # swing_type は三振 (plate_result_id=13) のときだけ意味を持ち、それ以外は NULL。
    # 三振以外は全件 NULL になるため単純インデックスでは選択性が極端に低い。
    # WHERE 句で「swing_type IS NOT NULL」に絞った部分インデックスにして
    # 三振の集計クエリでのみ実利を得るようにする。
    add_index :plate_appearances, :swing_type, where: 'swing_type IS NOT NULL'
  end
end
