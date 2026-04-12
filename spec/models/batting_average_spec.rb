require 'rails_helper'

RSpec.describe BattingAverage, type: :model do
  let(:user) { create(:user) }

  describe '.filtered_aggregate_for_user' do
    let!(:game_2024_regular) do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 15), match_type: 'regular')
      create(:batting_average, game_result: gr, user:, hit: 3, at_bats: 4, home_run: 1, times_at_bat: 5)
      gr
    end

    let!(:game_2024_open) do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 8, 20), match_type: 'open')
      create(:batting_average, game_result: gr, user:, hit: 1, at_bats: 3, home_run: 0, times_at_bat: 4)
      gr
    end

    let!(:game_2023_regular) do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2023, 9, 1), match_type: 'regular')
      create(:batting_average, game_result: gr, user:, hit: 2, at_bats: 5, home_run: 0, times_at_bat: 5)
      gr
    end

    it 'returns aggregated stats for all games when no filter is given' do
      result = described_class.filtered_aggregate_for_user(user.id).take
      expect(result.hit.to_i).to eq(6) # 3+1+2
      expect(result.at_bats.to_i).to eq(12) # 4+3+5
      expect(result.home_run.to_i).to eq(1)
    end

    it 'filters by year' do
      result = described_class.filtered_aggregate_for_user(user.id, year: '2024').take
      expect(result.hit.to_i).to eq(4) # 3+1
      expect(result.at_bats.to_i).to eq(7) # 4+3
    end

    it 'filters by match_type' do
      result = described_class.filtered_aggregate_for_user(user.id, match_type: 'regular').take
      expect(result.hit.to_i).to eq(5) # 3+2
      expect(result.at_bats.to_i).to eq(9) # 4+5
    end

    it 'filters by both year and match_type' do
      result = described_class.filtered_aggregate_for_user(user.id, year: '2024', match_type: 'regular').take
      expect(result.hit.to_i).to eq(3)
      expect(result.at_bats.to_i).to eq(4)
    end

    it 'skips year filter when year is "通算"' do
      result = described_class.filtered_aggregate_for_user(user.id, year: '通算').take
      expect(result.hit.to_i).to eq(6)
    end

    it 'skips match_type filter when match_type is "全て"' do
      result = described_class.filtered_aggregate_for_user(user.id, match_type: '全て').take
      expect(result.hit.to_i).to eq(6)
    end

    it 'returns nil when no games match the filter' do
      result = described_class.filtered_aggregate_for_user(user.id, year: '2022').take
      expect(result).to be_nil
    end
  end

  describe '.filtered_stats_for_user' do
    before do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 15), match_type: 'regular')
      create(:batting_average, game_result: gr, user:,
                               hit: 3, at_bats: 10, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                               times_at_bat: 12, base_on_balls: 2, strike_out: 3, hit_by_pitch: 0,
                               sacrifice_hit: 0, sacrifice_fly: 0)
    end

    it 'returns calculated stats hash with expected keys' do
      result = described_class.filtered_stats_for_user(user.id, year: '2024')
      expect(result).to include(:batting_average, :on_base_percentage, :slugging_percentage, :ops, :iso, :bb_per_k, :isod)
    end

    it 'calculates batting_average correctly' do
      result = described_class.filtered_stats_for_user(user.id, year: '2024')
      # total_hits = hit(3) + two_base_hit(1) + three_base_hit(0) + home_run(1) = 5
      # batting_average = 5 / 10 = 0.5
      expect(result[:batting_average]).to eq(0.5)
    end

    it 'returns all-zero calculated stats when no games match the filter' do
      other_user = create(:user)
      result = described_class.filtered_stats_for_user(other_user.id, year: '2022')
      # SUM without GROUP BY returns a row with NULL values, which become 0
      expect(result[:batting_average]).to eq(0)
      expect(result[:on_base_percentage]).to eq(0)
      expect(result[:total_hits]).to eq(0)
    end

    it 'handles zero at_bats gracefully' do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2025, 1, 10))
      create(:batting_average, game_result: gr, user:,
                               hit: 0, at_bats: 0, times_at_bat: 0, base_on_balls: 1, strike_out: 0,
                               two_base_hit: 0, three_base_hit: 0, home_run: 0)

      result = described_class.filtered_stats_for_user(user.id, year: '2025')
      expect(result[:batting_average]).to eq(0)
      expect(result[:on_base_percentage]).to eq(1.0)
    end
  end

  describe 'must_have_any_stats validation' do
    let(:game_result) { create(:game_result, user:) }

    it 'is invalid when all stat fields are zero' do
      ba = described_class.new(
        game_result:, user:,
        times_at_bat: 0, at_bats: 0, hit: 0, two_base_hit: 0, three_base_hit: 0,
        home_run: 0, total_bases: 0, runs_batted_in: 0, run: 0, strike_out: 0,
        base_on_balls: 0, hit_by_pitch: 0, sacrifice_hit: 0, sacrifice_fly: 0,
        stealing_base: 0, caught_stealing: 0, error: 0
      )
      expect(ba).not_to be_valid
      expect(ba.errors[:base]).to include('打撃成績が未入力です')
    end

    it 'is invalid when all stat fields are nil' do
      ba = described_class.new(game_result:, user:)
      expect(ba).not_to be_valid
      expect(ba.errors[:base]).to include('打撃成績が未入力です')
    end

    it 'is valid when at least one stat field is non-zero' do
      ba = described_class.new(
        game_result:, user:,
        times_at_bat: 0, at_bats: 0, hit: 0, two_base_hit: 0, three_base_hit: 0,
        home_run: 0, total_bases: 0, runs_batted_in: 1, run: 0, strike_out: 0,
        base_on_balls: 0, hit_by_pitch: 0, sacrifice_hit: 0, sacrifice_fly: 0,
        stealing_base: 0, caught_stealing: 0, error: 0
      )
      expect(ba).to be_valid
    end
  end
end
