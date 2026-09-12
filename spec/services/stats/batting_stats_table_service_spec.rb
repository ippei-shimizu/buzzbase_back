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
end
