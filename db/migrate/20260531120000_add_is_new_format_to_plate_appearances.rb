class AddIsNewFormatToPlateAppearances < ActiveRecord::Migration[7.0]
  def change
    add_column :plate_appearances, :is_new_format, :boolean, default: false, null: false
    add_index :plate_appearances, :is_new_format
  end
end
