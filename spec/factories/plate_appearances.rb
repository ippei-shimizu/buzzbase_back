FactoryBot.define do
  factory :plate_appearance do
    game_result
    user
    sequence(:batter_box_number) { |n| n }
    batting_result { 'ヒット' }
  end
end
