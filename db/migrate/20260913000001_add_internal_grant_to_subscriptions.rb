class AddInternalGrantToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    # 録画・審査・開発用に手動で Pro 化したレコードを課金分析から除外するためのフラグ。
    # started_at が null かどうかで判別する運用は、webhook 欠損など別要因でも null になりうるため採用しない。
    add_column :subscriptions, :internal_grant, :boolean, default: false, null: false
    add_column :subscriptions, :internal_grant_reason, :string
  end
end
