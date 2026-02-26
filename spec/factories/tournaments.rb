FactoryBot.define do
  factory :tournament do
    sequence(:name) { |n| "大会#{n}" }
  end
end
