require 'rails_helper'
require 'rake'

RSpec.describe 'data:backfill_batting_averages' do # rubocop:disable RSpec/DescribeClass
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task['data:backfill_batting_averages'] }
  let(:user) { create(:user) }

  before { task.reenable }

  context '新仕様 PA がある試合で batting_average が欠落しているとき' do
    let!(:game_result) { create(:game_result, user:) }

    before do
      # callback での auto-create を抑止するため、PA を直接 SQL で挿入する
      # （バックフィルが必要な「旧来の runner 経由で作られたデータ」の再現）。
      PlateAppearance.skip_callback(:commit, :after, :recalculate_game_batting_average)
      create(:plate_appearance, game_result:, user:, is_new_format: true,
                                plate_result_id: Stats::BattingAverageRecalculator::SINGLE_HIT_ID)
      PlateAppearance.set_callback(:commit, :after, :recalculate_game_batting_average)
    end

    it 'バックフィルで batting_average が新規作成される' do
      expect do
        task.invoke
      end.to change { BattingAverage.where(game_result_id: game_result.id).count }.from(0).to(1)
    end

    context 'DRY_RUN=1 のとき' do
      around do |example|
        ENV['DRY_RUN'] = '1'
        example.run
      ensure
        ENV.delete('DRY_RUN')
      end

      it 'batting_average は変更しない' do
        expect do
          task.invoke
        end.not_to(change { BattingAverage.where(game_result_id: game_result.id).count })
      end
    end
  end

  context '混在試合（旧 PA を含む）のとき' do
    let!(:game_result) { create(:game_result, user:) }
    let!(:legacy_batting_average) { create(:batting_average, game_result:, user:, hit: 99, at_bats: 99) }

    before do
      PlateAppearance.skip_callback(:commit, :after, :recalculate_game_batting_average)
      create(:plate_appearance, game_result:, user:, is_new_format: false,
                                plate_result_id: Stats::BattingAverageRecalculator::SINGLE_HIT_ID)
      create(:plate_appearance, game_result:, user:, is_new_format: true,
                                plate_result_id: Stats::BattingAverageRecalculator::HOME_RUN_ID,
                                batter_box_number: 2)
      PlateAppearance.set_callback(:commit, :after, :recalculate_game_batting_average)
    end

    it '直書きされた batting_average を触らない（recalculator 内の new_format_game? で skip）' do
      task.invoke
      expect(legacy_batting_average.reload.hit).to eq(99)
      expect(legacy_batting_average.at_bats).to eq(99)
    end
  end

  context 'PA が 1 件もない試合のとき' do
    let!(:game_result) { create(:game_result, user:) }

    it 'batting_average は作成されない（skip）' do
      expect do
        task.invoke
      end.not_to(change { BattingAverage.where(game_result_id: game_result.id).count })
    end
  end
end
