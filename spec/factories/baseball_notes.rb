FactoryBot.define do
  factory :baseball_note do
    user
    memo { nil }

    transient do
      improvement_theme { nil }
    end

    after(:create) do |note, evaluator|
      note.improvement_themes << evaluator.improvement_theme if evaluator.improvement_theme
    end
  end
end
