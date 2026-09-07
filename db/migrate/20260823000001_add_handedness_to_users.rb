class AddHandednessToUsers < ActiveRecord::Migration[7.1]
  def change
    # NULL は「未設定」を表す。プロフィールの任意項目のため NOT NULL 制約は付けない。
    add_column :users, :throw_hand, :integer
    add_column :users, :batting_side, :integer
  end
end
