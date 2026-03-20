FactoryBot.define do
  factory :notification do
    actor { association :user }
  end
end
