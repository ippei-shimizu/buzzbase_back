class AddInningFormatToMatchResults < ActiveRecord::Migration[7.0]
  def change
    add_column :match_results, :inning_format, :integer, null: false, default: 9
  end
end
