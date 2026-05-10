class AddAppearanceTypeToMatchResults < ActiveRecord::Migration[7.0]
  def change
    add_column :match_results, :appearance_type, :string, null: false, default: 'starter'
  end
end
