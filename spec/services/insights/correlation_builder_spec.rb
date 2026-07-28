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

    it '登板が無いユーザーには投手のカードを含めない' do
      record_week(0, swings: 100, at_bats: 4, hits: 1)
      keys = described_class.new(user:).call.pluck(:key)
      expect(keys).to include('swings_vs_ba')
      expect(keys).not_to include('practice_days_vs_era')
    end

    it 'ユーザー定義の組み合わせを自作カードとして返す' do
      record_week(0, swings: 100, at_bats: 4, hits: 1)
      combo = create(:insight_combination, user:, input_type: 'sleep_hours', metric: 'ops')
      cards = described_class.new(user:).call(combinations: [combo])
      custom = cards.find { |card| card[:id] == combo.id }
      expect(custom[:key]).to eq("custom_#{combo.id}")
      expect(custom[:title]).to eq('睡眠時間とOPS')
    end

    # 試合のみ記録し練習を一度もしていないユーザーが対象。
    # game_result 保存時に activity_log が作られるが、practice_menu_count/total_swing_count は
    # 0 のまま、intensity_level だけ試合により L4 になる。
    def record_game_only_week(offset_weeks, at_bats:, hits:)
      day = week_start(offset_weeks)
      game = create(:game_result, user:)
      game.match_result.update!(date_and_time: Time.utc(day.year, day.month, day.day, 12))
      create(:batting_average, user:, game_result: game, at_bats:, hit: hits,
                               two_base_hit: 0, three_base_hit: 0, home_run: 0, strike_out: 0, plate_appearances: at_bats)
    end

    it '練習を一度もしていないユーザーには素振り本数のカードを断定表示しない（入力値が全週0で変動が無いため）' do
      record_game_only_week(0, at_bats: 4, hits: 3)
      record_game_only_week(1, at_bats: 4, hits: 2)
      record_game_only_week(2, at_bats: 4, hits: 0)
      record_game_only_week(3, at_bats: 4, hits: 0)

      swings_card = described_class.new(user:).call.find { |card| card[:key] == 'swings_vs_ba' }
      expect(swings_card[:sufficient]).to be false
      expect(swings_card[:direction]).to eq('unknown')
    end

    it '試合のみの日は「練習した日数」に含めない' do
      record_game_only_week(0, at_bats: 4, hits: 3)
      record_game_only_week(1, at_bats: 4, hits: 2)
      record_game_only_week(2, at_bats: 4, hits: 0)
      record_game_only_week(3, at_bats: 4, hits: 0)

      practice_days_card = described_class.new(user:).call.find { |card| card[:key] == 'practice_days_vs_ops' }
      expect(practice_days_card[:sufficient]).to be false
    end
  end
end
