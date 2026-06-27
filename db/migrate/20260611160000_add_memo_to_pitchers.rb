class AddMemoToPitchers < ActiveRecord::Migration[7.0]
  def change
    add_column :pitchers, :memo, :text
  end
end
