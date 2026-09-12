FactoryBot.define do
  factory :menu_set do
    user
    sequence(:name) { |n| "メニューセット#{n}" }
    sort_order { 0 }
  end
end
