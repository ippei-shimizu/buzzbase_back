FactoryBot.define do
  factory :stadium do
    sequence(:name) { |n| "Stadium#{n}" }
  end
end
