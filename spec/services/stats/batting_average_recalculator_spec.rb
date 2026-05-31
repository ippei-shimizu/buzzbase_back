require 'rails_helper'

RSpec.describe Stats::BattingAverageRecalculator, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  describe '#call' do
    context '新仕様試合（is_new_format=true の打席が1件以上ある場合）' do
      before do
        # is_new_format=true の打席を 4 件作成: ヒット, 単打, 二塁打, 三振
        create(:plate_appearance, game_result:, user:, plate_result_id: 7, hit_direction_id: 10,
                                  is_new_format: true, rbi: 1, run_scored: 0, stolen_bases: 0, caught_stealing: 0)
        create(:plate_appearance, game_result:, user:, plate_result_id: 8, hit_direction_id: 8,
                                  is_new_format: true, rbi: 2, run_scored: 0, stolen_bases: 0, caught_stealing: 0)
        create(:plate_appearance, game_result:, user:, plate_result_id: 13, hit_direction_id: nil,
                                  is_new_format: true, rbi: 0, run_scored: 0, stolen_bases: 0, caught_stealing: 0)
        create(:plate_appearance, game_result:, user:, plate_result_id: 15, hit_direction_id: nil,
                                  is_new_format: true, rbi: 0, run_scored: 0, stolen_bases: 1, caught_stealing: 0)
      end

      it 'batting_average レコードを find_or_create_by + assign する' do
        described_class.new(game_result_id: game_result.id).call

        batting_average = BattingAverage.find_by(game_result_id: game_result.id)
        expect(batting_average).to be_present
        expect(batting_average.user_id).to eq(user.id)
      end

      it '主要カラムが plate_result_id ベースで集計される' do
        described_class.new(game_result_id: game_result.id).call
        batting_average = BattingAverage.find_by(game_result_id: game_result.id)

        aggregate_failures do
          expect(batting_average.plate_appearances).to eq(4)
          expect(batting_average.at_bats).to eq(3)              # 7,8,13 が counted_in_at_bats: true（15=四球は false）
          expect(batting_average.times_at_bat).to eq(3)
          expect(batting_average.hit).to eq(2)                  # 7 (単打) + 8 (二塁打)
          expect(batting_average.two_base_hit).to eq(1)
          expect(batting_average.three_base_hit).to eq(0)
          expect(batting_average.home_run).to eq(0)
          expect(batting_average.total_bases).to eq(3)          # 単打 1 + 二塁打 2
          expect(batting_average.strike_out).to eq(1)
          expect(batting_average.base_on_balls).to eq(1)
          expect(batting_average.runs_batted_in).to eq(3)       # rbi の sum
          expect(batting_average.stealing_base).to eq(1)
        end
      end

      it '同 game_result_id に再度呼ばれても結果は安定する（idempotent）' do
        described_class.new(game_result_id: game_result.id).call
        batting_average_first = BattingAverage.find_by(game_result_id: game_result.id).attributes.except('updated_at')

        described_class.new(game_result_id: game_result.id).call
        batting_average_second = BattingAverage.find_by(game_result_id: game_result.id).attributes.except('updated_at')

        expect(batting_average_second).to eq(batting_average_first)
      end
    end

    context '旧仕様試合（すべての打席が is_new_format=false）' do
      let!(:existing_batting_average) do
        create(:batting_average, game_result:, user:,
                                 at_bats: 99, hit: 88, total_bases: 77)
      end

      before do
        create(:plate_appearance, game_result:, user:, plate_result_id: 7, hit_direction_id: 10,
                                  is_new_format: false, batting_result: '中安')
      end

      it 'call は nil を返し、既存 batting_average の値を改変しない' do
        result = described_class.new(game_result_id: game_result.id).call

        expect(result).to be_nil
        existing_batting_average.reload
        expect(existing_batting_average.at_bats).to eq(99)
        expect(existing_batting_average.hit).to eq(88)
        expect(existing_batting_average.total_bases).to eq(77)
      end
    end

    context '新仕様試合で batting_average レコードがまだ無い場合' do
      before do
        create(:plate_appearance, game_result:, user:, plate_result_id: 7, hit_direction_id: 10,
                                  is_new_format: true)
      end

      it 'find_or_create_by で新規作成される' do
        expect do
          described_class.new(game_result_id: game_result.id).call
        end.to change { BattingAverage.where(game_result_id: game_result.id).count }.from(0).to(1)
      end
    end

    context '新仕様試合の最後の打席が削除されて新仕様打席がゼロになった場合' do
      let!(:orphan_batting_average) { create(:batting_average, game_result:, user:, at_bats: 1, hit: 1) }

      # 削除後を想定して plate_appearance は作成しない（new_format_game? = false）

      it 'cleanup_orphan: true で対応する batting_average を削除する（孤立レコード防止）' do
        expect do
          described_class.new(game_result_id: game_result.id, cleanup_orphan: true).call
        end.to change { BattingAverage.where(id: orphan_batting_average.id).count }.from(1).to(0)
      end

      it 'cleanup_orphan: false（デフォルト）の場合は触らない（旧仕様試合の batting_average 保護）' do
        described_class.new(game_result_id: game_result.id).call
        expect(BattingAverage.find_by(id: orphan_batting_average.id)).to be_present
      end
    end

    context 'user_id を引数で渡した場合' do
      before do
        create(:plate_appearance, game_result:, user:, plate_result_id: 7, hit_direction_id: 10,
                                  is_new_format: true)
      end

      it 'GameResult への追加クエリなしで batting_average.user_id を設定する' do
        described_class.new(game_result_id: game_result.id, user_id: user.id).call
        batting_average = BattingAverage.find_by(game_result_id: game_result.id)
        expect(batting_average.user_id).to eq(user.id)
      end
    end
  end
end
