FactoryBot.define do
  factory :hit_direction do
    sequence(:name) { |n| "Direction#{n}" }
    sequence(:display_order) { |n| 100 + n }
    zone_polygon do
      { 'depth' => nil,
        'polygon' => [{ 'x' => 0.0, 'y' => 0.0 }, { 'x' => 1.0, 'y' => 0.0 }, { 'x' => 1.0, 'y' => 1.0 }, { 'x' => 0.0, 'y' => 1.0 }] }
    end
  end
end
