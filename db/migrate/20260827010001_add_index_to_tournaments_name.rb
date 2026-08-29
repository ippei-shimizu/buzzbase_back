class AddIndexToTournamentsName < ActiveRecord::Migration[7.1]
  # 大会作成を名前検索ベースの冪等な処理に変えたため、毎回シーケンシャルスキャンにならないよう index を張る。
  # 既存の同名重複を統合していないのでユニークにはできない（統合は別途対応する）。
  def change
    add_index :tournaments, :name
  end
end
