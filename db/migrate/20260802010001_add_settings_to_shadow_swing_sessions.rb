class AddSettingsToShadowSwingSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :shadow_swing_sessions, :interval_seconds, :decimal, precision: 4, scale: 1, null: false, default: 5.0
    add_column :shadow_swing_sessions, :vibration_enabled, :boolean, null: false, default: false
    add_column :shadow_swing_sessions, :sound_enabled, :boolean, null: false, default: true
    add_column :shadow_swing_sessions, :voice_enabled, :boolean, null: false, default: false
  end
end
