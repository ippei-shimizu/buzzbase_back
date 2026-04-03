class RemapBattingPositionIds < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE plate_appearances SET batting_position_id = 12 WHERE batting_position_id = 9"
    execute "UPDATE plate_appearances SET batting_position_id = 10 WHERE batting_position_id = 8"
    execute "UPDATE plate_appearances SET batting_position_id = 8 WHERE batting_position_id = 7"
  end

  def down
    execute "UPDATE plate_appearances SET batting_position_id = 7 WHERE batting_position_id = 8"
    execute "UPDATE plate_appearances SET batting_position_id = 8 WHERE batting_position_id = 10"
    execute "UPDATE plate_appearances SET batting_position_id = 9 WHERE batting_position_id = 12"
  end
end
