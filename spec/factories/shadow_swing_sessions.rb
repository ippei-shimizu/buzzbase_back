FactoryBot.define do
  factory :shadow_swing_session do
    user
    logged_on { Time.find_zone('Asia/Tokyo').today }
    target_count { 200 }
    swing_count { 0 }
  end
end
