require 'rails_helper'

RSpec.describe PitchingResult, type: :model do
  let(:user) { create(:user) }

  describe '.filtered_pitching_aggregate_for_user' do
    let!(:game_2024_regular) do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 15), match_type: 'regular')
      create(:pitching_result, game_result: gr, user:,
                               win: 1, loss: 0, innings_pitched: 7.0, earned_run: 2, strikeouts: 8,
                               base_on_balls: 1, hits_allowed: 4)
      gr
    end

    let!(:game_2024_open) do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 8, 20), match_type: 'open')
      create(:pitching_result, game_result: gr, user:,
                               win: 0, loss: 1, innings_pitched: 5.0, earned_run: 4, strikeouts: 3,
                               base_on_balls: 3, hits_allowed: 6)
      gr
    end

    let!(:game_2023_regular) do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2023, 9, 1), match_type: 'regular')
      create(:pitching_result, game_result: gr, user:,
                               win: 1, loss: 0, innings_pitched: 9.0, earned_run: 0, strikeouts: 10,
                               base_on_balls: 2, hits_allowed: 3)
      gr
    end

    it 'returns aggregated stats for all games when no filter is given' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id).take
      expect(result.win.to_i).to eq(2)
      expect(result.loss.to_i).to eq(1)
      expect(result.strikeouts.to_i).to eq(21) # 8+3+10
      expect(result.innings_pitched.to_f).to eq(21.0) # 7+5+9
    end

    it 'filters by year' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id, year: '2024').take
      expect(result.win.to_i).to eq(1)
      expect(result.loss.to_i).to eq(1)
      expect(result.strikeouts.to_i).to eq(11) # 8+3
      expect(result.innings_pitched.to_f).to eq(12.0)
    end

    it 'filters by match_type' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id, match_type: 'regular').take
      expect(result.win.to_i).to eq(2)
      expect(result.strikeouts.to_i).to eq(18) # 8+10
    end

    it 'filters by both year and match_type' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id, year: '2024', match_type: 'regular').take
      expect(result.win.to_i).to eq(1)
      expect(result.strikeouts.to_i).to eq(8)
      expect(result.innings_pitched.to_f).to eq(7.0)
    end

    it 'skips year filter when year is "通算"' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id, year: '通算').take
      expect(result.strikeouts.to_i).to eq(21)
    end

    it 'skips match_type filter when match_type is "全て"' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id, match_type: '全て').take
      expect(result.strikeouts.to_i).to eq(21)
    end

    it 'returns nil when no games match the filter' do
      result = described_class.filtered_pitching_aggregate_for_user(user.id, year: '2022').take
      expect(result).to be_nil
    end
  end

  describe '.filtered_pitching_stats_for_user' do
    before do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 15), match_type: 'regular')
      create(:pitching_result, game_result: gr, user:,
                               win: 1, loss: 0, innings_pitched: 9.0, earned_run: 2, strikeouts: 10,
                               base_on_balls: 2, hits_allowed: 5)
    end

    it 'returns calculated stats hash with expected keys' do
      result = described_class.filtered_pitching_stats_for_user(user.id, year: '2024')
      expect(result).to include(:era, :win_percentage, :whip, :k_per_nine, :bb_per_nine, :k_bb)
    end

    it 'calculates ERA correctly' do
      result = described_class.filtered_pitching_stats_for_user(user.id, year: '2024')
      # ERA = (earned_run * 9) / innings_pitched = (2 * 9) / 9 = 2.0
      expect(result[:era]).to eq(2.0)
    end

    it 'calculates win_percentage correctly' do
      result = described_class.filtered_pitching_stats_for_user(user.id, year: '2024')
      # win_percentage = wins / (wins + losses) = 1 / (1 + 0) = 1.0
      expect(result[:win_percentage]).to eq(1.0)
    end

    it 'calculates WHIP correctly' do
      result = described_class.filtered_pitching_stats_for_user(user.id, year: '2024')
      # WHIP = (BB + hits_allowed) / IP = (2 + 5) / 9 = 0.778
      expect(result[:whip]).to eq(0.778)
    end

    it 'returns nil when no games match the filter' do
      result = described_class.filtered_pitching_stats_for_user(user.id, year: '2022')
      expect(result).to be_nil
    end

    it 'handles zero innings_pitched gracefully' do
      gr = create(:game_result, user:)
      gr.match_result.update!(date_and_time: Time.zone.local(2025, 1, 10))
      create(:pitching_result, game_result: gr, user:,
                               win: 0, loss: 0, innings_pitched: 0.0, earned_run: 0, strikeouts: 1,
                               base_on_balls: 0, hits_allowed: 0)

      result = described_class.filtered_pitching_stats_for_user(user.id, year: '2025')
      expect(result[:era]).to eq(0)
      expect(result[:whip]).to eq(0)
    end
  end

  describe 'must_have_any_stats validation' do
    let(:game_result) { create(:game_result, user:) }

    it 'is invalid when all stat fields are zero and got_to_the_distance is false' do
      pr = described_class.new(
        game_result:, user:,
        win: 0, loss: 0, hold: 0, saves: 0, innings_pitched: 0.0,
        number_of_pitches: 0, got_to_the_distance: false,
        run_allowed: 0, earned_run: 0, hits_allowed: 0, home_runs_hit: 0,
        strikeouts: 0, base_on_balls: 0, hit_by_pitch: 0
      )
      expect(pr).not_to be_valid
      expect(pr.errors[:base]).to include('投手成績が未入力です')
    end

    it 'is invalid when all stat fields are nil' do
      pr = described_class.new(game_result:, user:)
      expect(pr).not_to be_valid
      expect(pr.errors[:base]).to include('投手成績が未入力です')
    end

    it 'is valid when at least one stat field is non-zero' do
      pr = described_class.new(
        game_result:, user:,
        win: 0, loss: 0, hold: 0, saves: 0, innings_pitched: 3.0,
        number_of_pitches: 0, got_to_the_distance: false,
        run_allowed: 0, earned_run: 0, hits_allowed: 0, home_runs_hit: 0,
        strikeouts: 0, base_on_balls: 0, hit_by_pitch: 0
      )
      expect(pr).to be_valid
    end

    it 'is valid when got_to_the_distance is true even if all numbers are zero' do
      pr = described_class.new(
        game_result:, user:,
        win: 0, loss: 0, hold: 0, saves: 0, innings_pitched: 0.0,
        number_of_pitches: 0, got_to_the_distance: true,
        run_allowed: 0, earned_run: 0, hits_allowed: 0, home_runs_hit: 0,
        strikeouts: 0, base_on_balls: 0, hit_by_pitch: 0
      )
      expect(pr).to be_valid
    end
  end
end
