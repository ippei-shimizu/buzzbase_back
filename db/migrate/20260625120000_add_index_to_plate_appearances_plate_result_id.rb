class AddIndexToPlateAppearancesPlateResultId < ActiveRecord::Migration[7.1]
  def change
    # 新仕様の各 Aggregator (HitDirectionAggregator / PlateAppearanceBreakdownService 等) が
    # plate_result_id を WHERE / GROUP BY 条件に使うが、他の FK 列と違いインデックスが無く
    # user_id 絞り込み後に seqscan になる。データ増加で顕在化する前に索引を張る。
    add_index :plate_appearances, :plate_result_id
  end
end
