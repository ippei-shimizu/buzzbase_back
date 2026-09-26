# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitchingFormulas do
  describe '.rates' do
    let(:base_args) do
      {
        weighted_earned_run: 27, weighted_strikeouts: 108, weighted_base_on_balls: 36,
        strikeouts: 12, base_on_balls: 4, hits_allowed: 11, win: 1, loss: 1
      }
    end

    it 'rounds ERA to 2 decimals and the other rates to 3 decimals' do
      innings = 14 + (1.0 / 3)

      expect(described_class.rates(**base_args, innings:)).to eq(
        era: 1.88,
        whip: 1.047,
        k_per_nine: 7.535,
        bb_per_nine: 2.512,
        k_bb: 3.0,
        win_percentage: 0.5
      )
    end

    it 'returns 0.0 for every rate when all denominators are zero' do
      args = base_args.merge(base_on_balls: 0, win: 0, loss: 0)

      expect(described_class.rates(**args, innings: 0.0).values).to all(eq(0.0))
    end
  end
end
