FactoryBot.define do
  factory :award do
    sequence(:title) { |n| "アワード#{n}" }
  end
end
