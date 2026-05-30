FactoryBot.define do
  factory :timing do
    sequence(:name) { |n| "Timing#{n}" }
    sequence(:display_order) { |n| 1000 + n }
  end
end
