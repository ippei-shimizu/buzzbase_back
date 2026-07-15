FactoryBot.define do
  factory :practice_session do
    user
    logged_on { Time.find_zone('Asia/Tokyo').today }
    memo { nil }

    transient do
      improvement_theme { nil }
    end

    after(:create) do |session, evaluator|
      session.improvement_themes << evaluator.improvement_theme if evaluator.improvement_theme
    end
  end
end
