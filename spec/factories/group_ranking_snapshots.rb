FactoryBot.define do
  factory :group_ranking_snapshot do
    group
    user
    stat_type { 'batting_average' }
    rank { 1 }
    value { 0.350 }
    snapshot_date { Date.current }
  end
end
