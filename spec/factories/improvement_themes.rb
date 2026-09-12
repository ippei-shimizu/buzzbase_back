FactoryBot.define do
  factory :improvement_theme do
    user
    sequence(:title) { |n| "肩の開きを抑える#{n}" }
    category { 'batting' }
    status { 'open' }
    started_on { Time.find_zone('Asia/Tokyo').today }

    trait :achieved do
      status { 'achieved' }
      achieved_on { Time.find_zone('Asia/Tokyo').today }
    end
  end
end
