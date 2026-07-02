FactoryBot.define do
  factory :condition_log do
    user
    logged_on { Time.find_zone('Asia/Tokyo').today }
    fatigue_level { 3 }
    physical_level { 3 }
    sleep_hours { 7.0 }
    mood { '好調' }
    injuries { [] }
  end
end
