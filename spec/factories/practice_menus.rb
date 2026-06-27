FactoryBot.define do
  factory :practice_menu do
    user
    sequence(:name) { |n| "練習メニュー#{n}" }
    category { 'batting' }
    unit { 'count' }
    unit_label { '本' }
    default_value { 200 }
    is_favorite { false }
    sort_order { 0 }
    archived { false }
  end
end
