FactoryBot.define do
  factory :menu_set_item do
    menu_set
    practice_menu
    target_value { 200 }
    sort_order { 0 }
  end
end
