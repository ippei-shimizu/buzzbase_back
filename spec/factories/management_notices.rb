FactoryBot.define do
  factory :management_notice do
    sequence(:title) { |n| "お知らせ#{n}" }
    body { 'お知らせ本文' }
    status { :draft }
    notified_at { nil }
    created_by { association :admin_user }

    trait :published do
      status { :published }
    end
  end
end
