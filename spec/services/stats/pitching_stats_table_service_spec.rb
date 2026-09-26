# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitchingStatsTableService, type: :service do
  let(:user) { create(:user) }

  def build_pitching_game(date:, pitching_attrs:)
    game_result = create(:game_result, user:)
    game_result.match_result.update!(date_and_time: Time.zone.parse(date), inning_format: 9)
    create(:pitching_result, game_result:, user:, **pitching_attrs)
  end

  describe '#call' do
    context 'when innings pitched include thirds' do
      before do
        build_pitching_game(date: '2026-04-01', pitching_attrs: { innings_pitched: 9.0, earned_run: 0 })
        build_pitching_game(date: '2026-04-08', pitching_attrs: { innings_pitched: 5 + (1.0 / 3), earned_run: 3 })
      end

      it 'computes the total row ERA from the unrounded innings total' do
        total_row = described_class.new(user_id: user.id, mode: :daily).call.last

        expect(total_row[:era]).to eq((27 / (14 + (1.0 / 3))).round(2))
      end

      it 'matches the ERA returned by PitchingSummaryAggregator' do
        total_row = described_class.new(user_id: user.id, mode: :daily).call.last
        summary = Stats::PitchingSummaryAggregator.new(user_id: user.id).call

        expect(total_row[:era]).to eq(summary[:era])
      end
    end
  end
end
