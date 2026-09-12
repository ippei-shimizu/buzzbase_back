FactoryBot.define do
  factory :insight_combination do
    user
    input_type { 'sleep_hours' }
    metric { 'batting_average' }
  end
end
