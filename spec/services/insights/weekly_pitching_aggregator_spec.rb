require 'rails_helper'

RSpec.describe Insights::WeeklyPitchingAggregator, type: :service do
  let(:user) { create(:user) }
  let(:monday) { Time.find_zone('Asia/Tokyo').today.beginning_of_week }

  def pitching(date, attrs)
    game_result = create(:game_result, user:)
    game_result.match_result.update!(date_and_time: date.in_time_zone('Asia/Tokyo').noon, **attrs.slice(:inning_format))
    create(:pitching_result, user:, game_result:, **attrs.except(:inning_format))
  end

  it '9回制のみなら ERA / BB9 は従来通り *9 で計算する' do
    pitching(monday, innings_pitched: 9.0, earned_run: 3, base_on_balls: 2, hits_allowed: 4, inning_format: 9)

    result = described_class.new(user:, since: monday - 7).call

    aggregate_failures do
      expect(result[monday][:era]).to eq(3.0)
      expect(result[monday][:whip]).to eq(0.67)
      expect(result[monday][:bb_per9]).to eq(2.0)
    end
  end

  it '7回制の登板は inning_format で加重し、9固定より低い ERA になる' do
    pitching(monday, innings_pitched: 7.0, earned_run: 7, base_on_balls: 0, hits_allowed: 0, inning_format: 7)

    result = described_class.new(user:, since: monday - 7).call

    # 9固定なら (7*9/7)=9.00 になるところ、7回制加重で (7*7/7)=7.00 になる。
    expect(result[monday][:era]).to eq(7.0)
  end
end
