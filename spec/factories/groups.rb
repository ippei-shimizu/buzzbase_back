FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "グループ#{n}" }
  end
end
