require 'rails_helper'

RSpec.describe V2::AllGameResultSerializer, type: :serializer do
  let(:user) { create(:user, name: 'テストユーザー', user_id: 'test_user_1') }
  let(:game_result) { create(:game_result, user:) }
  let!(:plate_appearance) { create(:plate_appearance, game_result:, user:) }
  let!(:pitching_result) { create(:pitching_result, game_result:, user:) }

  let(:serializer) { described_class.new(game_result) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer).as_json }

  it 'includes game_result_id' do
    expect(serialization[:game_result_id]).to eq(game_result.id)
  end

  it 'includes user_id' do
    expect(serialization[:user_id]).to eq(user.id)
  end

  it 'includes user_name' do
    expect(serialization[:user_name]).to eq('テストユーザー')
  end

  it 'includes user_image' do
    expect(serialization).to have_key(:user_image)
  end

  it 'includes user_user_id' do
    expect(serialization[:user_user_id]).to eq('test_user_1')
  end

  it 'includes match_result' do
    expect(serialization[:match_result]).to be_present
  end

  it 'includes plate_appearances' do
    expect(serialization[:plate_appearances]).to be_an(Array)
  end

  it 'includes pitching_result' do
    expect(serialization[:pitching_result]).to be_present
  end

  it 'does not include batting_average' do
    expect(serialization).not_to have_key(:batting_average)
  end
end
