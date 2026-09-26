# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitchingSummaryAggregator, type: :service do
  let(:user) { create(:user) }

  def build_pitching_game(date: '2026-04-01', match_type: 'regular', inning_format: 9, pitching_attrs: {})
    game_result = create(:game_result, user:)
    game_result.match_result.update!(date_and_time: Time.zone.parse(date), match_type:, inning_format:)
    create(:pitching_result, game_result:, user:, **pitching_attrs)
    game_result
  end

  describe '#call' do
    context 'when there are no appearances' do
      it 'returns zero for all stats without NaN or Infinity' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:appearances]).to eq(0)
          expect(result[:innings_pitched]).to eq(0.0)
          %i[era whip k_per_nine bb_per_nine k_bb win_percentage].each do |key|
            expect(result[key]).to eq(0.0)
          end
        end
      end
    end

    context 'when the user has multiple appearances' do
      before do
        build_pitching_game(pitching_attrs: {
                              win: 1, loss: 0, hold: 0, saves: 0, innings_pitched: 9.0,
                              got_to_the_distance: true, run_allowed: 0, earned_run: 0,
                              hits_allowed: 4, home_runs_hit: 0, strikeouts: 8, base_on_balls: 2,
                              hit_by_pitch: 1, number_of_pitches: 110
                            })
        build_pitching_game(date: '2026-04-08', pitching_attrs: {
                              win: 0, loss: 1, hold: 0, saves: 0, innings_pitched: 5 + (1.0 / 3),
                              got_to_the_distance: false, run_allowed: 4, earned_run: 3,
                              hits_allowed: 7, home_runs_hit: 1, strikeouts: 4, base_on_balls: 2,
                              hit_by_pitch: 0, number_of_pitches: 90
                            })
      end

      it 'returns summed counts and innings in thirds' do
        result = described_class.new(user_id: user.id).call

        expect(result).to include(
          appearances: 2, win: 1, loss: 1, hold: 0, saves: 0,
          complete_games: 1, shutouts: 1, number_of_pitches: 200,
          hits_allowed: 11, home_runs_hit: 1, strikeouts: 12, base_on_balls: 4,
          hit_by_pitch: 1, run_allowed: 4, earned_run: 3, innings_pitched: 14.33
        )
      end

      it 'computes rates from the unrounded innings total' do
        result = described_class.new(user_id: user.id).call
        innings = 14 + (1.0 / 3)

        aggregate_failures do
          expect(result[:era]).to eq((3 * 9 / innings).round(2))
          expect(result[:whip]).to eq((15 / innings).round(3))
          expect(result[:k_per_nine]).to eq((12 * 9 / innings).round(3))
          expect(result[:bb_per_nine]).to eq((4 * 9 / innings).round(3))
          expect(result[:k_bb]).to eq(3.0)
          expect(result[:win_percentage]).to eq(0.5)
        end
      end

      it 'does not expose the inning-format weighted intermediate sums' do
        result = described_class.new(user_id: user.id).call

        expect(result.keys).not_to include(:weighted_earned_run, :weighted_strikeouts, :weighted_base_on_balls)
      end
    end

    it 'weights ERA by the inning format of each game' do
      build_pitching_game(inning_format: 7, pitching_attrs: { innings_pitched: 7.0, earned_run: 2 })

      result = described_class.new(user_id: user.id).call

      expect(result[:era]).to eq(2.0)
    end

    it 'does not count a complete game with a blank run allowed as a shutout' do
      build_pitching_game(pitching_attrs: { got_to_the_distance: true, run_allowed: nil })

      result = described_class.new(user_id: user.id).call

      expect(result).to include(complete_games: 1, shutouts: 0)
    end

    it 'does not count games with zero innings pitched as appearances' do
      build_pitching_game(pitching_attrs: { innings_pitched: 0.0, earned_run: 3 })

      result = described_class.new(user_id: user.id).call

      aggregate_failures do
        expect(result[:appearances]).to eq(0)
        expect(result[:earned_run]).to eq(0)
      end
    end

    it 'does not include other users pitching results' do
      other_user = create(:user)
      other_game = create(:game_result, user: other_user)
      create(:pitching_result, game_result: other_game, user: other_user)

      result = described_class.new(user_id: user.id).call

      expect(result[:appearances]).to eq(0)
    end

    describe 'filters' do
      before do
        build_pitching_game(date: '2025-06-01', match_type: 'regular', pitching_attrs: { strikeouts: 5 })
        build_pitching_game(date: '2026-06-01', match_type: 'regular', pitching_attrs: { strikeouts: 7 })
        build_pitching_game(date: '2026-07-01', match_type: 'open', pitching_attrs: { strikeouts: 3 })
      end

      it 'filters by year' do
        result = described_class.new(user_id: user.id, year: '2026').call

        expect(result).to include(appearances: 2, strikeouts: 10)
      end

      it 'filters by match type' do
        result = described_class.new(user_id: user.id, match_type: 'regular').call

        expect(result).to include(appearances: 2, strikeouts: 12)
      end

      it 'combines year and match type filters' do
        result = described_class.new(user_id: user.id, year: '2026', match_type: 'open').call

        expect(result).to include(appearances: 1, strikeouts: 3)
      end
    end
  end
end
