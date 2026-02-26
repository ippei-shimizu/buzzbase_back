require 'rails_helper'

RSpec.describe V2::GameResultSerializer, type: :serializer do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }
  let!(:plate_appearance) { create(:plate_appearance, game_result:, user:, batter_box_number: 1, batting_result: 'ヒット') }
  let!(:batting_average) { create(:batting_average, game_result:, user:) }
  let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

  let(:serializer) { described_class.new(game_result) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer).as_json }

  it 'includes game_result_id' do
    expect(serialization[:game_result_id]).to eq(game_result.id)
  end

  it 'includes nested match_result' do
    expect(serialization[:match_result]).to be_present
    expect(serialization[:match_result][:id]).to eq(game_result.match_result.id)
  end

  it 'includes plate_appearances as array' do
    expect(serialization[:plate_appearances]).to be_an(Array)
    expect(serialization[:plate_appearances].length).to eq(1)
    expect(serialization[:plate_appearances].first[:batting_result]).to eq('ヒット')
  end

  it 'includes batting_average' do
    expect(serialization[:batting_average]).to be_present
    expect(serialization[:batting_average][:hit]).to eq(1)
  end

  it 'includes pitching_result' do
    expect(serialization[:pitching_result]).to be_present
    expect(serialization[:pitching_result][:win]).to eq(1)
  end
end
