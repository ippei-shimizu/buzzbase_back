FactoryBot.define do
  factory :cancellation_feedback do
    user
    subscription { user.subscription }
    reason { 'expensive' }
    note { nil }

    trait :with_note do
      note { 'もう少し安ければ続けたかった' }
    end
  end
end
