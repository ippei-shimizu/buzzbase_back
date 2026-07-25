FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
    name { Faker::Name.name }
    confirmed_at { Time.current }
    uid { email }
    provider { 'email' }

    trait :unconfirmed do
      confirmed_at { nil }
      confirmation_token { Devise.friendly_token }
      confirmation_sent_at { Time.current }
    end

    trait :google do
      provider { 'google' }
      password { nil }
      password_confirmation { nil }
    end

    trait :apple do
      provider { 'apple' }
      password { nil }
      password_confirmation { nil }
    end
  end
end
