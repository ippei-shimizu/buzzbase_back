FactoryBot.define do
  factory :periodic_review do
    user
    period_type { 'weekly' }
    period_start { Time.find_zone('Asia/Tokyo').today.beginning_of_week - 7 }
    period_end { period_start + 6 }
    summary { { 'practice_days' => 5, 'total_swings' => 1500 } }
    read { false }

    trait :monthly do
      period_type { 'monthly' }
      period_start { Time.find_zone('Asia/Tokyo').today.prev_month.beginning_of_month }
      period_end { period_start.end_of_month }
    end
  end
end
