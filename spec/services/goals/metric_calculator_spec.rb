require 'rails_helper'

RSpec.describe Goals::MetricCalculator do
  let(:user) { create(:user) }

  # 打撃/投手レコードは当月の試合（game_result → match_result）に紐づけて作る。
  def batting(attrs)
    create(:batting_average, user:, game_result: create(:game_result, user:), **attrs)
  end

  def pitching(attrs)
    create(:pitching_result, user:, game_result: create(:game_result, user:), **attrs)
  end

  describe '#current_value（追加した自動集計指標）' do
    it '本塁打(home_runs)を期間内で合計する' do
      batting(home_run: 2)
      batting(home_run: 1)
      goal = create(:goal, user:, metric_key: 'home_runs', target_value: 3)

      expect(described_class.new(goal).current_value).to eq(3)
    end

    it '安打(hits)は単打+二塁打+三塁打+本塁打を合計する' do
      batting(hit: 2, two_base_hit: 1, three_base_hit: 0, home_run: 1)
      goal = create(:goal, user:, metric_key: 'hits', target_value: 5)

      expect(described_class.new(goal).current_value).to eq(4)
    end

    it '奪三振(strikeouts)を期間内で合計する' do
      pitching(strikeouts: 6)
      pitching(strikeouts: 4)
      goal = create(:goal, user:, metric_key: 'strikeouts', target_value: 10)

      expect(described_class.new(goal).current_value).to eq(10)
    end

    it 'WHIP(whip)は (与四球+被安打)/投球回 を返す' do
      pitching(base_on_balls: 2, hits_allowed: 5, innings_pitched: 7.0)
      goal = create(:goal, user:, metric_key: 'whip', comparison_type: 'less_than', target_value: 1.2)

      expect(described_class.new(goal).current_value).to eq(1.0)
    end

    it 'メニュー継続日数(menu_practice_days)は対象メニューの実施日数（同日複数回は1日）を数える' do
      menu = create(:practice_menu, user:)
      month = Time.find_zone('Asia/Tokyo').today.beginning_of_month
      create(:practice_log, user:, practice_menu: menu, logged_on: month + 5)
      create(:practice_log, user:, practice_menu: menu, logged_on: month + 5) # 同日2回目 → 1日扱い
      create(:practice_log, user:, practice_menu: menu, logged_on: month + 6)
      create(:practice_log, user:, practice_menu: create(:practice_menu, user:), logged_on: month + 5) # 別メニュー
      goal = create(:goal, user:, metric_key: 'menu_practice_days', practice_menu: menu, target_value: 20)

      expect(described_class.new(goal).current_value).to eq(2)
    end
  end
end
