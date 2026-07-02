FactoryBot.define do
  factory :practice_log do
    user
    practice_menu { association :practice_menu, user: }
    logged_on { Time.find_zone('Asia/Tokyo').today }
    amount { 100 }
    menu_name { practice_menu&.name || 'メニュー' }
    unit_label { '本' }
    source { 'manual' }

    # 素振りカウンターが完了時に自動生成するログ。
    trait :shadow_swing do
      practice_menu { nil }
      menu_name { '素振り' }
      unit_label { '本' }
      source { 'shadow_swing' }
    end
  end
end
