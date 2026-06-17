class AddSwingTypeToPlateAppearances < ActiveRecord::Migration[7.1]
  def change
    add_column :plate_appearances, :swing_type, :integer
    add_index :plate_appearances, :swing_type
  end
end
