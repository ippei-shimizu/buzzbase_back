FactoryBot.define do
  factory :hit_depth do
    sequence(:name) { |n| "HitDepth#{n}" }
    sequence(:display_order) { |n| 1000 + n }
  end
end
