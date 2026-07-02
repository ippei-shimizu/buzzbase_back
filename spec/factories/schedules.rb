FactoryBot.define do
  factory :schedule do
    user
    title { '朝の素振り' }
    days_of_week { '1,3,5' }
    scheduled_time { '06:00' }
    notification_enabled { true }
    active { true }
  end
end
