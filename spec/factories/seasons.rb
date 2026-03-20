FactoryBot.define do
  factory :season do
    user
    sequence(:name) { |n| "Season#{2020 + n}" }
  end
end
