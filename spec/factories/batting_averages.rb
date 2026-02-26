FactoryBot.define do
  factory :batting_average do
    game_result
    user
    plate_appearances { 4 }
    times_at_bat { 4 }
    at_bats { 3 }
    hit { 1 }
    two_base_hit { 0 }
    three_base_hit { 0 }
    home_run { 0 }
    total_bases { 1 }
    runs_batted_in { 0 }
    run { 0 }
    strike_out { 1 }
    base_on_balls { 0 }
    hit_by_pitch { 0 }
    sacrifice_hit { 0 }
    sacrifice_fly { 0 }
    stealing_base { 0 }
    caught_stealing { 0 }
    error { 0 }
  end
end
