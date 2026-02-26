FactoryBot.define do
  factory :match_result do
    game_result
    user
    my_team { association :team }
    opponent_team { association :team }
    date_and_time { Time.current }
    match_type { 'regular' }
    my_team_score { 5 }
    opponent_team_score { 3 }
    batting_order { '4' }
    defensive_position { 'ショート' }
    tournament { nil }
    memo { nil }
  end
end
