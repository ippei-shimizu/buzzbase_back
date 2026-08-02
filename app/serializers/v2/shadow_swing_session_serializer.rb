module V2
  class ShadowSwingSessionSerializer < ActiveModel::Serializer
    attributes :id, :logged_on, :target_count, :swing_count, :completed_at, :practice_log_id,
               :interval_seconds, :vibration_enabled, :sound_enabled, :voice_enabled

    # decimal のままだと JSON に文字列で出るため、クライアントがそのまま数値として扱えるようにする。
    def interval_seconds
      object.interval_seconds.to_f
    end
  end
end
