FactoryBot.define do
  factory :game_result do
    user

    after(:create) do |game_result|
      if game_result.match_result_id.nil? && game_result.match_result.nil?
        my_team = create(:team)
        opponent_team = create(:team)
        match_result = create(:match_result,
                              game_result:,
                              user: game_result.user,
                              my_team:,
                              opponent_team:)
        game_result.update!(match_result_id: match_result.id)
      end
    end
  end
end
