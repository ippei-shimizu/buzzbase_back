class NormalizeMatchTypeValues < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE match_results SET match_type = 'regular' WHERE match_type = '公式戦'"
    execute "UPDATE match_results SET match_type = 'open' WHERE match_type = 'オープン戦'"
  end

  def down
    # 元の値を復元する方法がないため、ロールバックは行わない
  end
end
