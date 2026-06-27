FactoryBot.define do
  factory :contact_quality do
    sequence(:name) { |n| "ContactQuality#{n}" }
    sequence(:display_order) { |n| 1000 + n }
  end
end
