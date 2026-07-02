FactoryBot.define do
  factory :goal do
    user
    title { '今月20日練習' }
    period_type { 'monthly' }
    month_start { Time.find_zone('Asia/Tokyo').today.beginning_of_month }
    deadline { Time.find_zone('Asia/Tokyo').today.end_of_month }
    metric_key { 'practice_days' }
    target_value { 20 }
    comparison_type { 'greater_than' }

    trait :tournament do
      tournament
      period_type { 'tournament' }
      month_start { nil }
      metric_key { 'batting_average' }
      target_value { 0.3 }
      deadline { Time.find_zone('Asia/Tokyo').today + 7.days }
    end
  end
end
