# frozen_string_literal: true

require 'rails_helper'

# game-stats-202605 リリースの最重要要件:
#   「既存ユーザーの集計値（batting_average 等）が変わらないこと」
#
# BattingAverageRecalculator は「全 PA が新仕様の試合」だけを再集計し、旧仕様試合・
# 混在試合では直書きされた既存集計値を保護する。本 spec はその不変性を実データ相当の
# 固定シードで保証する（ガードが緩むと差分で必ず落ちる）。
RSpec.describe 'BattingAverage invariance on recalculation', type: :service do # rubocop:disable RSpec/DescribeClass
  let(:seed) { GoldenMasterSeed.build! }

  # batting_average のうち集計値カラムのみ（id / timestamps は比較対象外）。
  def stat_columns
    %w[
      plate_appearances times_at_bat at_bats hit two_base_hit three_base_hit home_run
      total_bases runs_batted_in run strike_out base_on_balls hit_by_pitch
      sacrifice_hit sacrifice_fly stealing_base caught_stealing error
    ]
  end

  def stat_snapshot(game_result_id)
    BattingAverage.where(game_result_id:).order(:id).map { |row| row.attributes.slice(*stat_columns) }
  end

  it '旧仕様試合では recalculator が既存の batting_average を一切変えない' do
    seed[:old_game_ids].each do |game_result_id|
      before = stat_snapshot(game_result_id)
      Stats::BattingAverageRecalculator.new(game_result_id:, user_id: seed[:user].id).call
      expect(stat_snapshot(game_result_id)).to eq(before)
    end
  end

  it '旧PAと新PAが混在する試合では recalculator が既存の batting_average を保護する' do
    game_result_id = seed[:mixed_game_id]
    before = stat_snapshot(game_result_id)
    Stats::BattingAverageRecalculator.new(game_result_id:, user_id: seed[:user].id).call
    expect(stat_snapshot(game_result_id)).to eq(before)
  end

  it '新仕様試合の再集計結果が golden と一致する' do
    snapshot = stat_snapshot(seed[:new_game_id])
    expect_golden('recalculated_batting_average', { rows: snapshot })
  end
end
