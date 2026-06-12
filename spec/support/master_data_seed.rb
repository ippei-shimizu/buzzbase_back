# Test DB にも開発・本番マイグレーション同様のマスタデータを投入する。
# maintain_test_schema! はスキーマ更新のみで、マイグレーション内の up シードは実行されないため、
# RSpec の before(:suite) で明示的にシードを流す。

RSpec.configure do |config|
  config.before(:suite) do
    %w[hit_directions plate_results pitch_types contact_qualities timings hit_depths
       arm_angles velocity_zones pitcher_styles appearance_situations].each do |table|
      MasterData::Seeder.from_yaml(ActiveRecord::Base.connection, table:, file: "#{table}.yml")
    end
  end
end
