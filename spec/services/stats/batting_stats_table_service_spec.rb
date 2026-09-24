# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::BattingStatsTableService, type: :service do
  let(:user) { create(:user) }

  def create_game(date:, hit:, at_bats:)
    game = create(:game_result, user:)
    game.match_result.update!(date_and_time: Time.zone.parse("#{date} 12:00:00"), match_type: 'regular')
    create(:batting_average, game_result: game, user:, hit:, at_bats:, total_bases: hit,
                             times_at_bat: at_bats)
  end

  describe 'monthly rows with a period spanning multiple years' do
    before do
      create_game(date: '2024-09-10', hit: 1, at_bats: 4)
      create_game(date: '2025-09-10', hit: 2, at_bats: 4)
      create_game(date: '2025-10-10', hit: 3, at_bats: 4)
    end

    # 期間が年をまたぐと、同じ「9月」でも 2024 と 2025 は別バケットにしないと打数が混ざる。
    it '年をまたぐ 9 月を別々の年月行に分ける（同月マージによる集計ズレを防ぐ）' do
      rows = described_class.new(
        user_id: user.id, mode: :monthly, start_month: '2024-09', end_month: '2025-10'
      ).call

      labels = rows.pluck(:label)
      aggregate_failures do
        expect(labels).to include('2024/9月', '2025/9月', '2025/10月')
        expect(labels).not_to include('9月')
        earlier_september = rows.find { |row| row[:label] == '2024/9月' }
        later_september = rows.find { |row| row[:label] == '2025/9月' }
        expect(earlier_september[:at_bats]).to eq(4)
        expect(later_september[:at_bats]).to eq(4)
      end
    end
  end

  describe 'monthly rows with a period within a single year' do
    before do
      create_game(date: '2025-05-10', hit: 1, at_bats: 4)
      create_game(date: '2025-07-10', hit: 2, at_bats: 4)
    end

    it '単年内の期間では従来どおり月粒度（"M月"）ラベルを使う' do
      rows = described_class.new(
        user_id: user.id, mode: :monthly, start_month: '2025-05', end_month: '2025-07'
      ).call

      labels = rows.pluck(:label)
      expect(labels).to include('5月', '7月')
    end
  end

  describe '走本塁打の内数' do
    def create_home_run_game(date:, home_run:, inside_the_park:, match_type: 'regular')
      game = create(:game_result, user:)
      game.match_result.update!(date_and_time: Time.zone.parse("#{date} 12:00:00"), match_type:)
      create(:batting_average, game_result: game, user:, hit: 0, at_bats: 4, times_at_bat: 4,
                               home_run:, total_bases: home_run * 4)
      inside_the_park.times do
        create(:plate_appearance, game_result: game, user:, plate_result_id: 10,
                                  is_new_format: true, home_run_type: :inside_the_park)
      end
      (home_run - inside_the_park).times do
        create(:plate_appearance, game_result: game, user:, plate_result_id: 10,
                                  is_new_format: true, home_run_type: :over_fence)
      end
      game
    end

    def find_row(rows, label)
      rows.find { |row| row[:label] == label }
    end

    it '年度行と通算行に本塁打の内数として走本塁打を返し、本塁打の総数は変わらない' do
      create_home_run_game(date: '2025-05-10', home_run: 2, inside_the_park: 1)
      create_home_run_game(date: '2026-05-10', home_run: 1, inside_the_park: 0)

      rows = described_class.new(user_id: user.id, mode: :yearly).call

      aggregate_failures do
        expect(find_row(rows, '2025')).to include(home_run: 2, inside_the_park_home_run: 1)
        expect(find_row(rows, '2026')).to include(home_run: 1, inside_the_park_home_run: 0)
        expect(find_row(rows, '通算')).to include(home_run: 3, inside_the_park_home_run: 1)
      end
    end

    it '月別行でも月ごとに走本塁打を数える' do
      create_home_run_game(date: '2026-05-10', home_run: 1, inside_the_park: 1)
      create_home_run_game(date: '2026-06-10', home_run: 1, inside_the_park: 0)

      rows = described_class.new(user_id: user.id, mode: :monthly, year: 2026).call

      aggregate_failures do
        expect(find_row(rows, '5月')[:inside_the_park_home_run]).to eq(1)
        expect(find_row(rows, '6月')[:inside_the_park_home_run]).to eq(0)
        expect(find_row(rows, '通算')[:inside_the_park_home_run]).to eq(1)
      end
    end

    it '日別行では試合ごとに走本塁打を数える' do
      create_home_run_game(date: '2026-05-10', home_run: 2, inside_the_park: 2)
      create_home_run_game(date: '2026-05-11', home_run: 1, inside_the_park: 0)

      rows = described_class.new(user_id: user.id, mode: :daily, year: 2026).call

      aggregate_failures do
        expect(find_row(rows, '05/10')[:inside_the_park_home_run]).to eq(2)
        expect(find_row(rows, '05/11')[:inside_the_park_home_run]).to eq(0)
        expect(find_row(rows, '通算')[:inside_the_park_home_run]).to eq(2)
      end
    end

    it '混在試合で batting_averages が古くても内数は母数を超えない' do
      # 旧 PA を含む混在試合では BattingAverageRecalculator が再集計しないため
      # home_run が 0 のまま新仕様の走本塁打 PA だけが増えうる。
      game = create_home_run_game(date: '2026-05-10', home_run: 0, inside_the_park: 0)
      create(:plate_appearance, game_result: game, user:, plate_result_id: 7, is_new_format: false)
      create(:plate_appearance, game_result: game, user:, plate_result_id: 10,
                                is_new_format: true, home_run_type: :inside_the_park)

      yearly = described_class.new(user_id: user.id, mode: :yearly).call
      daily = described_class.new(user_id: user.id, mode: :daily, year: 2026).call

      aggregate_failures do
        expect(find_row(yearly, '2026')).to include(home_run: 0, inside_the_park_home_run: 0)
        expect(find_row(daily, '05/10')).to include(home_run: 0, inside_the_park_home_run: 0)
      end
    end

    it '別ユーザーの走本塁打は数えない' do
      other_user = create(:user)
      other_game = create(:game_result, user: other_user)
      other_game.match_result.update!(date_and_time: Time.zone.parse('2026-05-10 12:00:00'))
      create(:batting_average, game_result: other_game, user: other_user, home_run: 1, total_bases: 4,
                               at_bats: 4, times_at_bat: 4)
      create(:plate_appearance, game_result: other_game, user: other_user, plate_result_id: 10,
                                is_new_format: true, home_run_type: :inside_the_park)
      create_home_run_game(date: '2026-05-10', home_run: 1, inside_the_park: 0)

      rows = described_class.new(user_id: user.id, mode: :yearly).call

      expect(find_row(rows, '2026')[:inside_the_park_home_run]).to eq(0)
    end

    it 'season_id フィルタは走本塁打にも効く' do
      season = create(:season, user:)
      season_game = create_home_run_game(date: '2026-05-10', home_run: 1, inside_the_park: 1)
      season_game.update!(season_id: season.id)
      create_home_run_game(date: '2026-05-11', home_run: 1, inside_the_park: 1)

      rows = described_class.new(user_id: user.id, mode: :yearly, season_id: season.id).call

      expect(find_row(rows, '2026')).to include(home_run: 1, inside_the_park_home_run: 1)
    end
  end
end
