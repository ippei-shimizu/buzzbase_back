FactoryBot.define do
  factory :pitching_result do
    game_result
    user
    win { 1 }
    loss { 0 }
    hold { 0 }
    saves { 0 }
    innings_pitched { 7.0 }
    number_of_pitches { 100 }
    got_to_the_distance { false }
    run_allowed { 2 }
    earned_run { 1 }
    hits_allowed { 5 }
    home_runs_hit { 0 }
    strikeouts { 6 }
    base_on_balls { 2 }
    hit_by_pitch { 0 }
  end
end
