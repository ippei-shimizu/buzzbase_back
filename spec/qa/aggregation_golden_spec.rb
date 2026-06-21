# frozen_string_literal: true

require 'rails_helper'

# 集計サービスの出力を固定データセットに対して golden 化する characterization テスト。
# 集計ロジックが意図せず変わると差分で必ず落ちる（リファクタの安全網）。
#
# golden を意図的に更新するとき:
#   SPEC_UPDATE_GOLDEN=1 bundle exec rspec spec/qa/aggregation_golden_spec.rb
RSpec.describe 'Aggregation golden master', type: :service do # rubocop:disable RSpec/DescribeClass
  let(:seed) { GoldenMasterSeed.build! }
  let(:user) { seed[:user] }

  it 'HeadlineStatsAggregator の出力が golden と一致する' do
    expect_golden('headline_stats', Stats::HeadlineStatsAggregator.new(user_id: user.id).call)
  end

  it 'HitDirectionAggregator の出力が golden と一致する' do
    expect_golden('hit_direction', Stats::HitDirectionAggregator.new(user_id: user.id).call)
  end

  it 'HitLocationAggregator の出力が golden と一致する' do
    expect_golden('hit_location', Stats::HitLocationAggregator.new(user_id: user.id).call)
  end

  it 'OutTypeBreakdownService の出力が golden と一致する' do
    expect_golden('out_type_breakdown', Stats::OutTypeBreakdownService.new(user_id: user.id).call)
  end

  it 'RunnersSituationAggregator の出力が golden と一致する' do
    expect_golden('runners_situation', Stats::RunnersSituationAggregator.new(user_id: user.id).call)
  end

  it 'BattingResultTextGenerator が各打席で生成する文言が golden と一致する' do
    texts = PlateAppearance.where(game_result_id: seed[:new_game_id])
                           .order(:batter_box_number)
                           .map { |plate_appearance| Stats::BattingResultTextGenerator.generate(plate_appearance) }
    expect_golden('batting_result_texts', { texts: })
  end
end
