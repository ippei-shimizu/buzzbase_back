require 'rails_helper'

RSpec.describe V2::PlateAppearanceSerializer, type: :serializer do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user: user) }
  let(:plate_appearance) do
    create(:plate_appearance,
           game_result: game_result,
           user: user,
           batter_box_number: 3,
           batting_result: 'ツーベースヒット')
  end

  let(:serializer) { described_class.new(plate_appearance) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer).as_json }

  it 'includes id' do
    expect(serialization[:id]).to eq(plate_appearance.id)
  end

  it 'includes batter_box_number' do
    expect(serialization[:batter_box_number]).to eq(3)
  end

  it 'includes batting_result' do
    expect(serialization[:batting_result]).to eq('ツーベースヒット')
  end

  it 'includes game_result_id' do
    expect(serialization[:game_result_id]).to eq(game_result.id)
  end
end
