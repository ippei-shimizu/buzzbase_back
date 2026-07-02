require 'rails_helper'

RSpec.describe Insights::CorrelationBuilder, type: :service do
  let(:user) { create(:user) }

  def week_start(offset_weeks)
    Time.find_zone('Asia/Tokyo').today.beginning_of_week - (offset_weeks * 7)
  end

  # 指定週に素振り量（shadow_swing の練習ログ → activity_log へ再計算）と打撃成績を作る。
  # total_swing_count は shadow_swing ログから DailyActivityRecalculator が集計する仕様のため、
  # activity_log を直接作らず実データ経路で用意する。
  def record_week(offset_weeks, swings:, at_bats:, hits:)
    day = week_start(offset_weeks)
    create(:practice_log, :shadow_swing, user:, logged_on: day, amount: swings)
    game = create(:game_result, user:)
    game.match_result.update!(date_and_time: Time.utc(day.year, day.month, day.day, 12))
    create(:batting_average, user:, game_result: game, at_bats:, hit: hits,
                             two_base_hit: 0, three_base_hit: 0, home_run: 0, strike_out: 0, plate_appearances: at_bats)
  end

  describe '#call' do
    it 'サンプル不足のペアは非断定カードを返す' do
      record_week(0, swings: 100, at_bats: 4, hits: 1)
      cards = described_class.new(user:).call
      swings_card = cards.find { |card| card[:key] == 'swings_vs_ba' }
      expect(swings_card[:sufficient]).to be false
      expect(swings_card[:direction]).to eq('unknown')
    end

    it '素振りが多い週ほど打率が高い傾向を検出する' do
      # 上位群（多素振り）を高打率、下位群（少素振り）を低打率にする
      record_week(0, swings: 500, at_bats: 4, hits: 3)
      record_week(1, swings: 450, at_bats: 4, hits: 2)
      record_week(2, swings: 50,  at_bats: 4, hits: 0)
      record_week(3, swings: 80,  at_bats: 4, hits: 0)

      swings_card = described_class.new(user:).call.find { |card| card[:key] == 'swings_vs_ba' }
      expect(swings_card[:sufficient]).to be true
      expect(swings_card[:direction]).to eq('positive')
      expect(swings_card[:sample_weeks]).to eq(4)
    end
  end
end
