FactoryBot.define do
  factory :activity_log do
    user
    activity_date { Time.find_zone('Asia/Tokyo').today }
    practice_menu_count { 1 }
    total_swing_count { 0 }
    has_game { false }
    intensity_level { 1 }
  end
end
