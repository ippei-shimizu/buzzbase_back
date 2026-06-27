FactoryBot.define do
  factory :pitch_type do
    sequence(:name) { |n| "PitchType#{n}" }
    sequence(:display_order) { |n| 1000 + n }
  end
end
