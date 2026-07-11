module V2
  class ShadowSwingSessionSerializer < ActiveModel::Serializer
    attributes :id, :logged_on, :target_count, :swing_count, :completed_at, :practice_log_id
  end
end
