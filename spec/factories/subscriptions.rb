FactoryBot.define do
  factory :subscription do
    user
    status { 'free' }
    revenuecat_entitlement_id { 'pro' }
    has_used_trial { false }
    is_early_subscriber { false }

    trait :free do
      status { 'free' }
    end

    trait :trial do
      status { 'trial' }
      started_at { 7.days.ago }
      expires_at { 7.days.from_now }
      has_used_trial { true }
    end

    trait :active do
      status { 'active' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 30.days.ago }
      expires_at { 30.days.from_now }
      has_used_trial { true }
    end

    trait :cancelled do
      status { 'cancelled' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 60.days.ago }
      expires_at { 5.days.from_now }
      cancelled_at { 2.days.ago }
      has_used_trial { true }
    end

    trait :billing_issue do
      status { 'billing_issue' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 60.days.ago }
      expires_at { 3.days.from_now }
      billing_issue_at { 1.day.ago }
      has_used_trial { true }
    end

    trait :expired do
      status { 'expired' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 90.days.ago }
      expires_at { 5.days.ago }
      has_used_trial { true }
    end
  end
end
