FactoryBot.define do
  factory :note_tag do
    user
    sequence(:name) { |n| "タグ#{n}" }

    trait :preset do
      user { nil }
      is_preset { true }
    end
  end
end
