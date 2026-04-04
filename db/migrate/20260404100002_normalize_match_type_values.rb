class NormalizeMatchTypeValues < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL.squish
      UPDATE match_results SET match_type = 'regular' WHERE match_type = '公式戦';
      UPDATE match_results SET match_type = 'open' WHERE match_type = 'オープン戦';
    SQL
  end

  def down
    # 元の値を復元する方法がないため、ロールバックは行わない
  end
end
