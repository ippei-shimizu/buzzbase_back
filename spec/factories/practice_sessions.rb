FactoryBot.define do
  factory :practice_session do
    user
    logged_on { Time.find_zone('Asia/Tokyo').today }
    memo { nil }
  end
end
