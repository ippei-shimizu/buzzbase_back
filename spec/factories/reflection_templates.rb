FactoryBot.define do
  factory :reflection_template do
    user
    sequence(:title) { |n| "自作テンプレ#{n}" }
    questions { %w[うまくいったこと 課題 次やること] }
    is_preset { false }
    is_default { false }

    trait :preset do
      user { nil }
      is_preset { true }
    end
  end
end
