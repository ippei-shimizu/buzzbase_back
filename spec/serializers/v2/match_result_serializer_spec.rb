require 'rails_helper'

RSpec.describe V2::MatchResultSerializer, type: :serializer do
  let(:user) { create(:user) }
  let(:opponent_team) { create(:team, name: '対戦相手チーム') }
  let(:tournament) { create(:tournament, name: 'テスト大会') }
  let(:game_result) { create(:game_result, user:) }

  let(:serializer) { described_class.new(game_result.match_result) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer).as_json }

  before do
    game_result.match_result.update!(
      opponent_team:,
      tournament:
    )
  end

  it 'includes all base attributes' do
    %i[id date_and_time match_type my_team_id opponent_team_id
       my_team_score opponent_team_score batting_order
       defensive_position tournament_id memo].each do |attr|
      expect(serialization).to have_key(attr)
    end
  end

  it 'includes opponent_team_name' do
    expect(serialization[:opponent_team_name]).to eq('対戦相手チーム')
  end

  it 'includes tournament_name' do
    expect(serialization[:tournament_name]).to eq('テスト大会')
  end

  context 'when tournament is nil' do
    before do
      game_result.match_result.update!(tournament: nil)
    end

    it 'returns nil for tournament_name' do
      expect(serialization[:tournament_name]).to be_nil
    end
  end
end
