# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::GameSummaryService, type: :service do
  let(:user) { create(:user) }

  describe '#call' do
    describe 'recent_form date' do
      it 'formats date_and_time in JST, not UTC' do
        game_result = create(:game_result, user:)
        # UTC 2026-07-14 17:00 = JST 2026-07-15 02:00。UTCのままだと前日(07/14)にずれる
        game_result.match_result.update!(date_and_time: Time.zone.parse('2026-07-15 02:00:00 +0900'))

        result = described_class.new(user_id: user.id).call
        recent = result[:recent_form].find { |g| g[:game_result_id] == game_result.id }

        expect(recent[:date]).to eq('07/15')
      end
    end
  end
end
