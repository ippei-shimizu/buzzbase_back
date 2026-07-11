require 'rails_helper'

RSpec.describe Goals::ProgressCalculator do
  let(:user) { create(:user) }

  def pitching(attrs)
    create(:pitching_result, user:, game_result: create(:game_result, user:), **attrs)
  end

  describe 'less_than 指標（低いほど良い）の進捗・達成判定' do
    let(:goal) { create(:goal, user:, metric_key: 'era', comparison_type: 'less_than', target_value: 1.0) }

    it '登板が無い場合はデータなしとして未達成・進捗0%' do
      calculator = described_class.new(goal)
      aggregate_failures do
        expect(calculator.current_value).to be_nil
        expect(calculator.progress_percent).to eq(0)
        expect(calculator.achieved?).to be false
      end
    end

    it '防御率0.00（真の0）はデータなしと区別され達成・進捗100%' do
      pitching(innings_pitched: 7.0, earned_run: 0)
      calculator = described_class.new(goal)
      aggregate_failures do
        expect(calculator.current_value).to eq(0.0)
        expect(calculator.progress_percent).to eq(100.0)
        expect(calculator.achieved?).to be true
      end
    end

    it '現在値が目標値を上回る間は 目標値/現在値 の進捗率で未達成' do
      pitching(innings_pitched: 9.0, earned_run: 2) # ERA 2.00
      calculator = described_class.new(goal)
      aggregate_failures do
        expect(calculator.progress_percent).to eq(50.0)
        expect(calculator.achieved?).to be false
      end
    end
  end
end
