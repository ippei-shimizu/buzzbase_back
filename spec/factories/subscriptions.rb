FactoryBot.define do
  # User の after_create :create_default_subscription が必ず free な subscription を
  # 作るため、create(:subscription) で 2 つ目を INSERT すると unique index 違反になる。
  # ここでは「ユーザーを作って、その既存 subscription を attributes で上書きする」戦略を取る。
  # build / build_stubbed では `user` が未保存なので after_create が走らず、そのまま使える。
  factory :subscription do
    transient do
      owner { nil }
    end

    user { owner || association(:user) }
    status { 'free' }
    has_used_trial { false }
    is_early_subscriber { false }

    to_create do |instance|
      # User の after_create で free subscription が既に作られているケースを考慮する。
      # association キャッシュが追従しないため、DB を直接見て existing を取得する。
      existing = Subscription.find_by(user_id: instance.user_id)
      if existing
        attrs = instance.attributes.except('id', 'created_at', 'updated_at')
        existing.update!(attrs)
        instance.id = existing.id
        instance.reload
      else
        instance.save!
      end
    end

    trait :free do
      status { 'free' }
    end

    trait :trial do
      status { 'trial' }
      started_at { 7.days.ago }
      expires_at { 7.days.from_now }
      has_used_trial { true }
      revenuecat_entitlement_id { 'pro' }
    end

    trait :active do
      status { 'active' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 30.days.ago }
      expires_at { 30.days.from_now }
      has_used_trial { true }
      revenuecat_entitlement_id { 'pro' }
    end

    trait :cancelled do
      status { 'cancelled' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 60.days.ago }
      expires_at { 5.days.from_now }
      cancelled_at { 2.days.ago }
      has_used_trial { true }
      revenuecat_entitlement_id { 'pro' }
    end

    trait :billing_issue do
      status { 'billing_issue' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 60.days.ago }
      expires_at { 3.days.from_now }
      billing_issue_at { 1.day.ago }
      has_used_trial { true }
      revenuecat_entitlement_id { 'pro' }
    end

    trait :expired do
      status { 'expired' }
      plan_type { 'monthly' }
      platform { 'ios' }
      started_at { 90.days.ago }
      expires_at { 5.days.ago }
      has_used_trial { true }
      revenuecat_entitlement_id { 'pro' }
    end

    trait :pending do
      status { 'pending' }
    end
  end
end
