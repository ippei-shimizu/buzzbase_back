FactoryBot.define do
  factory :goal_badge do
    user
    goal
    badge_type { 'monthly_achieved' }
    badge_name { '月間目標達成' }
    awarded_at { Time.current }
  end
end
