FactoryBot.define do
  factory :plate_result do
    sequence(:name) { |n| "Result#{n}" }
    sequence(:display_order) { |n| 100 + n }
    hit_direction_required { true }
    counted_in_at_bats { true }
  end
end
